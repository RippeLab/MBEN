import numpy as np
import cv2
from skimage import exposure
import argparse
import os


def get_arguments():	
	"""
	Parses and checks command line arguments, and provides an help text.
	Assumes 4 or more and returns 4 or more positional command line arguments:
	src_file = Path to the source image 
	dst_file = Path to the target image
	output_folder = Path to the output folder
	other_images = Other images to transform
	"""
	parser = argparse.ArgumentParser(description = """
		Registers the source image to the destination image and then all other
		provided images using the same transformation.
	""")
	parser.add_argument("src_file", help = "path to the source file")
	parser.add_argument("dst_file", help = "path to the target image file")
	parser.add_argument("output_folder", help = "Path to the output folder")
	parser.add_argument("other_images", help = "Other images to transform", nargs = "*",
		default = [])
	args = parser.parse_args()
	return args.src_file, args.dst_file, args.output_folder, args.other_images

def claher(img):
	"""
	Runs Contrast Limited Adaptive Histogram Equalization (CLAHE)
	on the image and converts it to 8bit
	"""
	img = exposure.equalize_adapthist(img, kernel_size = 127, clip_limit = 0.01, nbins = 256)
	img = img / img.max() #normalizes img in range 0 - 255
	img = 255 * img
	img = img.astype(np.uint8)
	return img

def makeoutpath(input_path, output_path_folder):
	filename = os.path.splitext(os.path.basename(input_path))[0] + "-Registered.tiff"
	pth = os.path.join(output_path_folder, filename)
	return pth

def get_transform(src_img, dst_img):
	# Initialize SIFT detector
	descriptor = cv2.SIFT_create()
	# Find the keypoints and descriptors with SIFT
	kp1, des1 = descriptor.detectAndCompute(src_img, None)
	kp2, des2 = descriptor.detectAndCompute(dst_img, None)
	# Brute force Matcher
	matcher = cv2.BFMatcher(cv2.NORM_L1, crossCheck = False)
	matches = matcher.knnMatch(des1, des2, k = 2)
	# Apply ratio test
	good_matches = []
	for m,n in matches:
		if m.distance < 0.75 * n.distance:
			good_matches.append([m])
	# Select good matched keypoints
	ref_matched_kpts = np.float32([kp1[m[0].queryIdx].pt for m in good_matches])
	sensed_matched_kpts = np.float32([kp2[m[0].trainIdx].pt for m in good_matches])
	# Compute homography
	homography, _  = cv2.estimateAffinePartial2D(ref_matched_kpts,
		sensed_matched_kpts, method = cv2.RANSAC, ransacReprojThreshold = 5)
	return homography

if __name__ == "__main__":
	# Read command line parameters
	src_image_path, dst_image_path, output_folder, other_images = get_arguments()
	# Load the images (force greyscale)
	src = cv2.imread(src_image_path, cv2.IMREAD_ANYDEPTH)
	dst = cv2.imread(dst_image_path, cv2.IMREAD_ANYDEPTH)
	# Rotate src 90 clockwise and flip horizontally
	src = np.rot90(src, k = 1, axes = (1,0))
	src = np.fliplr(src)
	# Equalize the image histograms 
	eq_src = claher(src)
	eq_dst = claher(dst)
	# Get the transformation from src to dst
	transf = get_transform(eq_src, eq_dst)
	# Warp the source image and save it (reload to preserve bit depth and color)
	src = cv2.imread(src_image_path, cv2.IMREAD_ANYDEPTH | cv.IMREAD_ANYCOLOR)
	src = np.rot90(src, k = 1, axes = (1,0))
	src = np.fliplr(src)
	warped_image = cv2.warpAffine(src, transf, (dst.shape[1], dst.shape[0]))
	cv2.imwrite(makeoutpath(src_image_path, output_folder), warped_image)
	# Warp the other images and save them
	for img_path in other_images:
		img = cv2.imread(img_path, cv2.IMREAD_ANYDEPTH | cv.IMREAD_ANYCOLOR)
		img = np.rot90(img, k = 1, axes = (1,0))
		img = np.fliplr(img)
		img_warped = cv2.warpAffine(img, transf, (dst.shape[1], dst.shape[0]))
		cv2.imwrite(makeoutpath(img_path, output_folder), img_warped)

