// Open the source image (CONFOCAL) and the target image (RESOLVE) 
sourcefile = File.openDialog("Source Image");
open(sourcefile)
rename("Source");

targetfile = File.openDialog("Target Image");
open(targetfile)
rename("Target");

// Mirror the source to match the target (OPTIONAL)
selectImage("Source");
run("Flip Vertically");
// Can add rotation here if necessary

// Extract features with SIFT
// The expected_transformation=Affine parameter is used only for filtering out bad features.
// The final transformation does not need to be an affine transform.
run("Extract SIFT Correspondences",
"source_image=Source "  +
"target_image=Target " +
"initial_gaussian_blur=1.60 steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=1024 " +
"feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/next_closest_ratio=0.92 " +
"filter maximal_alignment_error=25 minimal_inlier_ratio=0.05 minimal_number_of_inliers=7 " +
"expected_transformation=Affine");

// Tranform the image using the extracted features
// Note the landmark_weight=1 parameter is changed from the default of 0
run("bUnwarpJ",
"source_image=Source " +
"target_image=Target " +
"registration=Mono image_subsample_factor=0 initial_deformation=Coarse " +
"final_deformation=[Very Fine] divergence_weight=0 curl_weight=0 landmark_weight=1 image_weight=1 " +
"consistency_weight=10 stop_threshold=0.01 verbose");

// Extract the registered image
selectImage("Registered Source Image");
run("Stack to Images");
close("Deformation Grid");
close("Deformation Field");
close("Warped Source Mask");
close("Target Image")

// Change the Registered image from 32 back to 16 bit (same bit depth of source and target)
selectImage("Registered Source Image");
setOption("ScaleConversions", true);
run("16-bit");

// Just for checking overlay the registered image with the Target (OPTIONAL)
run("Merge Channels...", "c1=[Registered Source Image] c2=Target create keep");

//  Saving
output = getDirectory("Output folder for results"); //;
saveAs("tiff", output + "registered.tiff");
