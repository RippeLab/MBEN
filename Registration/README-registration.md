# RESOLVE_tools
Tentative set of tools and scripts for analysing spatial transcriptomic data with the resolve platform

## Contents:
+ 1) [Fiji Macro](#FijiMacro)
+ 2) [Python and OpenCV registration](#OpenCVpy)

# 1) Fiji Macro <a name="FijiMacro"></a>
FiJi [macro](https://github.com/MicheleBortol/RESOLVE_tools/blob/main/bin/FIJI_REGISTRATION.ijm) for the registration of DAPI images from the RESOLVE and confocal microscopes.

**Usage**      
The script can be run interactively as a Fiji Macro. The script works as follows:
1) Ask the user for the pahts to open the `source` (Confocal) and `target` (Resolve) images.
2) Vertically mirrors the `source` to match the `target`.
3) Extract features with SIFT from both images and match them.
4) Tranform the `source` image using the extracted features to identify the transformation.
5) Extract only the `registered` image from the stack generated at point 4).
6) Change the `registered` image from 32 back to 16 bit (same bit depth of ´source´ and ´target´).
7) Create a RED (`registered`) and GREEN (`target`) image for checking the registration quality.
8) Save the `registered` image to a directory selected by the user as: `registered.tiff`.

**Warning:**  
+ The script can require a lot of memory for large images.
+ If there are many empty areas in the target image, the registered image will be heavily distorted in their proximity.
+ The script assumes that the source image needs to be vertically mirrored.


# 2) Python and OpenCV registration <a name="#OpenCVpy"></a>

**Overview:**  
The registration works in the following way:
1) Load source and target images
2) Rotate the source image clockwise by 90 degrees (optional)
3) Equalize the histograms of both images
4) Flip horizontally the source images
5) Try to identify 10000 SIFT features in each image
6) Match the feautures across the two images
7) Apply ratio test (75%) to the matches
8) Calculate the transformation from source to target
9) Transform the source image and save it
10) Transform the other images and save them

The transformed images have the same name as the original with the
´-Registered.tiff´ suffix added to it.

There is an additional batch script working as a helper that:
1) Downloads a singularity container with the dependencies
2) Clones the [MindaGap repository](https://github.com/ViriatoII/MindaGap.git)
3) Runs MindaGap on the target image (optional)
4) Given the input folder identifies the source, target and other images to register.
5) Creates the output folder
6) Runs the python script to perform the registration

**Usage**  
+ Bash helper script:
	+ Input:
		+ IN_FOLDER: path to the input folder
		+ OUT_FOLDER: path to the output folder
		+ DO_MINDAGAP: set to "true" to run Mindagap on the Resolve image
		+ ROTATE: set to true to rotate the Resolve image by 90 degrees clockwise
	+ Details:
		+ The source image is the one containing "*405nm*" in its name.
		+ The target image is the one whose name ends with *_Channel3_R8_.tiff".
		+ The other image to align mathch this regex ".+[0-9]{3}nm.+" excluding the source image.
		+ If MindaGap is applied the corrected target image has this suffix added: "gridfilled.tif"

+ Python script only:
	+ Requirements:
		+ numpy
		+ opencv for python3

	+ Input:
		+ src_file: path to the source file to be registered
		+ dst_file: path to the image file to be used as a target for the registration
		+ output_folder: path for output.
		+ rotate: Rotate clockwise 90 degrees the source and all other images before registration.
		+ other_images: Other images to transform.
		
