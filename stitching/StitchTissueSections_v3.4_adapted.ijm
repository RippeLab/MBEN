close("*");

//set some options
setOption("ExpandableArrays", true);
setBatchMode(true);

function GetTimeString() {
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString = "Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+"\nTime: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
	return TimeString;
}

function GetShortTimeString() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	ShortTimeString = "" + year + "-";
	month = month + 1;
	if (month < 10) {ShortTimeString = ShortTimeString + "0";}
	ShortTimeString = ShortTimeString + month + "-";
	if (dayOfMonth<10) {ShortTimeString = ShortTimeString+"0";}
	ShortTimeString = ShortTimeString+dayOfMonth+"_";
	if (hour<10) {ShortTimeString = ShortTimeString+"0";}
	ShortTimeString = ShortTimeString+hour+"h";
	if (minute<10) {ShortTimeString = ShortTimeString+"0";}
	ShortTimeString = ShortTimeString+minute+"m";
	if (second<10) {ShortTimeString = ShortTimeString+"0";}
	ShortTimeString = ShortTimeString+second+"s";
	return ShortTimeString;
}

function SetLUTResetContrast(LUT){
	//selectWindow(stack);
	Stack.getDimensions(width, height, channels, slices, frames);
	for(j=0; j<channels; j++){
		Stack.setChannel(j+1);
		run(LUT);
		setMinAndMax(0, 65535);				
		}
	}

// get directory and create and open a log file
dir = getDirectory("Choose the directory of your experiment (containing the ims files and a metadata file");
infiles = getFileList(dir);
logfile = File.open(dir + GetShortTimeString() + "_log.txt");
print(logfile, "This is version 3.4");
print(logfile, "Run started:\n" + GetTimeString());
print(logfile, "Analyzing data in " + dir);
File.close(logfile);

//initialize some arrays
meta = newArray;
laser_on = newArray;
wavelengths = newArray;
correct = newArray;
ffgain = newArray;

//extract the channel and stitching configuration as well as the objective from the metadata file
for(i=0; i<infiles.length; i++){
	if (endsWith(infiles[i], "metadata.txt")){
		meta = Array.concat(meta,infiles[i]);
		}
	}

if (meta.length == 0){
	exit("No metadata file found.");
	} else {
		if (meta.length > 1){
		Dialog.create("Multiple metadata files were found. Select one to extract the channel, objective and montage information from.");
		Dialog.addChoice("metadata file:", meta);
		Dialog.show();
		meta = Dialog.getChoice();
		File.append("Using " + meta + " to extract channel information.", logfile);
		meta = dir + meta;
		}else{
			meta = dir + meta[0];
			}
		}
 
ctrl=0;
montage=0;
objective=0;
camera=0;
lns = split(File.openAsString(meta), "\n");
for (j=0; j<lns.length; j++){
	lns[j]=replace(lns[j], "\t", "");
	
	//extract existing laser lines and their wavelengths
	if (startsWith(lns[j], "{DisplayName=Laser Wavelength")) {
		lambda=split(lns[j],"=");
		laser=replace(lambda[1], "Laser Wavelength ", "");
		laser=replace(laser, ", Value", "");
		laser=parseInt(laser);
		lambda=replace(lambda[2], "}", "");
		lambda=parseInt(lambda);
		List.set(laser, lambda);
		} else if (lns[j] == "[Imaging Modes In Protocol]"){
			ctrl=1;
			} else if (lns[j] == "[FieldMontageProtocolSpecification]"){
				montage=1;
				}
		
	//extract used laser lines and stitch parameters (i. e. tiling dimensions)
	if (startsWith(lns[j], "{DisplayName=Laser") && endsWith(lns[j], "True}") && ctrl == 0){
		temp = replace(lns[j], "\\{DisplayName=Laser ", "");
		temp = replace(temp, ", Value=True}", "");
		laser_on = Array.concat(laser_on, parseInt(temp));
		} else if (startsWith(lns[j], "Rows") && montage == 1){
			temp = replace(lns[j],"Rows=", "");
			y_grid = temp;
			} else if (startsWith(lns[j], "Columns") && montage == 1){
				temp = replace(lns[j], "Columns=", "");
				x_grid = temp;
				} else if (startsWith(lns[j], "Overlap") && montage == 1){
					temp = replace(lns[j], "Overlap=", "");
					o=temp;
					}
		
	//extract the objective information from the metadata file
	if (startsWith(lns[j], "{DisplayName=Select Objective") && objective == 0){
		temp=split(lns[j], " - ");
		objective = split(temp[4], "/");
		objective = objective[0];		
		}
	
	//extract the camera information from the metadata file
	if (startsWith(lns[j], "AcquisitionDeviceAlias=") && camera == 0){
		temp=split(lns[j], " ");
		camera = temp[1]+temp[2];
		}
	
	}

//remove first element of laser_on --> when using the twin cam, the Zyla laser is listed twice as on
//laser_on = Array.slice(laser_on,1);     

//get the list with all existing lasers and their corresponding wavelengths
laser = List.getList;

for (n=0; n<laser_on.length; n++){
	wavelengths = Array.concat(wavelengths,List.get(laser_on[n]));
	}	
	
File.append("Found " + wavelengths.length + " active channels with the following excitation wavelengths:", logfile);

for (n=0; n<wavelengths.length; n++){
	File.append(wavelengths[n] + " nm", logfile);
	}

//specify if stitching should be carried out
Dialog.create("Tile scan stitching");
Dialog.addCheckbox("The input images are part of a tile scan and should be stitched (otherwise, images will only be converted and possibly corrected).", true);
Dialog.show();
stitchchoice = Dialog.getCheckbox();

print(stitchchoice);

if (stitchchoice == 1){
	//choose the channel to be used for stitching (usually DAPI)
	Dialog.create("Select channel(s) to be used for stitching.\n If multiple channels are selected, a maximum intensity projection of them will be used.");
	for (n=0; n<wavelengths.length; n++){
		Dialog.addCheckbox(wavelengths[n] + " nm", true);
		}
	Dialog.show();
	for (n=0; n<wavelengths.length; n++){
		stitch = Array.concat(stitch,Dialog.getCheckbox());
		}
	//remove additional array value (first)
	stitch = Array.deleteIndex(stitch, 0);
	
	//get the index and the wavelengths of the channel(s) to be used for stitching
	for (n=0; n<wavelengths.length; n++){
		if (stitch[n]==1){
			stitch_index = Array.concat(stitch_index, n+1);
			stitch_channel = Array.concat(stitch_channel, wavelengths[n]);
			}
		}
	stitch_index = Array.deleteIndex(stitch_index, 0);
	stitch_channel = Array.deleteIndex(stitch_channel, 0);
	stitch_print = String.join(stitch_channel, ",");
	File.append("Stitching a "+ x_grid + " x " + y_grid + " image with " + o + "% overlap between the tiles based on the " + stitch_print + " nm channel(s).", logfile);
	} else {
		File.append("No stitching will be performed.", logfile);
		}

//select the channels that should be corrected (flatfield AND chromatic aberation)
Dialog.create("Flatfield and chromatic aberation correction:");
for (n=0; n<wavelengths.length; n++){
	Dialog.addCheckbox(wavelengths[n] + " nm", true);
	}
Dialog.show();
for (n=0; n<wavelengths.length; n++){
	correct = Array.concat(correct,Dialog.getCheckbox());
	}

File.append("Correcting the flatfield using the " + objective + " correction files for " + camera, logfile);

//create some folders for results
subdir = dir;
tempdir = subdir + "_temp/";
outdirmax = subdir + "_TIF_MaxProj/";
fused = subdir + "_Fused/";
stitchdir = outdirmax + "_Stitch/";
if (stitchchoice == 1){
	File.makeDirectory(fused);
	}
File.makeDirectory(tempdir);
File.makeDirectory(tempdir + "out/");
File.makeDirectory(outdirmax);
File.makeDirectory(stitchdir);
for (n=0; n<wavelengths.length; n++){
	File.makeDirectory(outdirmax + "/_" + wavelengths[n] + "/");
	if (correct[n]==1){
		File.makeDirectory(outdirmax + "/_" + wavelengths[n] + "/_corrected");
		}
	}

//empty stitch folder (in case macro was run before)

templist = getFileList(stitchdir);					
for (i=0; i<templist.length; i++) {
     File.delete(stitchdir+templist[i]);
}

//get gain files for flatfield correction
correctdir =  getDirectory("Choose the directory with the gain files for correction");
for (n=0; n<wavelengths.length; n++){
	gainfile=correctdir + camera + "-" + wavelengths[n] + "nm-" + objective + "-2022-05-16_GainImage.tif";
	ffgain=Array.concat(ffgain,gainfile);
	}
ffdark = correctdir + camera + "darkCounts.tif";

File.append("Using the following gain files for flatfield correction:", logfile);

for (n=0; n<ffgain.length; n++){
	File.append(ffgain[n], logfile);
	}

File.append("Using " + ffdark + " as dark count image for flatfield correction", logfile);

//get transform folder for chromatic aberration correction
transformdir =  getDirectory("Choose the directory for chromatic aberration correction");

//do the tiff-converstation, max proj and flatfield correction
for(i=0; i<infiles.length; i++) {
	if (endsWith(infiles[i], ".ims")){
		filenm = subdir+infiles[i];
		check = outdirmax+"MAX_"+replace(infiles[i], ".ims", ".tif");
		print(check);
		if (File.exists(check)){
			open(check);
			rename("MAX_Stack");
			} else {
				print("Converting file "+(i+1)+"/"+infiles.length+" ("+infiles[i]+")");
				run("Bio-Formats (Windowless)", "open=filenm");
				SetLUTResetContrast("Grays");
				rename("3DStack");
				run("Z Project...", "projection=[Max Intensity]");
				setMinAndMax(0, 65535);
				saveAs("Tiff", outdirmax+"MAX_"+infiles[i]);
				rename("MAX_Stack");
				close("3DStack");
				}
		for (j=0; j<wavelengths.length; j++){
			channel_index=j+1;
			outdirmaxch = outdirmax + "/_" + wavelengths[j] + "/"; 
			selectImage("MAX_Stack");
			run("Duplicate...", "duplicate channels=channel_index-channel_index");
			setMinAndMax(0, 65535);
			saveAs("Tiff", outdirmaxch+wavelengths[j]+"nm_MAX_"+infiles[i]);
			rename("Raw");
			if (correct[j]==0){
				print("No correction for " + wavelengths[j] + " nm images. Continuing with next channel...");
				close("Raw");
				continue;
				}
			print("Correcting flatfield and chromatic aberation for "+wavelengths[j]+" nm channel for "+infiles[i]);
			File.append("Correcting flatfield and chromatic aberation for "+wavelengths[j]+" nm channel for "+infiles[i], logfile);
			// calculate the corrected Image (RawImage-Dark) x Gain
			open(ffgain[j]);
			rename("gain");
			setMinAndMax(0, 65535);
			open(ffdark);
			rename("dark");
			setMinAndMax(0, 65535);
			imageCalculator("Subtract create", "Raw", "dark");
			rename("raw_minus_dark");
			run("32-bit");
			setMinAndMax(0, 65535);
			imageCalculator("Multiply create 32-bit", "raw_minus_dark" , "gain");
			rename("corr_Image");  //flatfield-corrected image
			setMinAndMax(0, 65535);
			run("16-bit");
			setMinAndMax(0, 65535);
			tempimage = wavelengths[j] + "nm_MAX_corr_"+replace(infiles[i], ".ims", ".tif"); 
			saveAs("Tiff", tempdir + tempimage);
			close();
			close("Raw");
			close("gain");
			close("dark");
			close("raw_minus_dark");
			run("Transform Virtual Stack Slices", "source=" + tempdir + " output=" + tempdir + "out transforms=" + transformdir+camera + "_" + wavelengths[j]+"nm_"+objective+" interpolate");
			close();
			open(tempdir + "out/" + tempimage);
			if (wavelengths[j] == 730 && camera == "EMCCD1" && objective == "100x") {
					makeRectangle(0, 1, 1024, 1024);
					run("Crop");
				}
			saveAs("Tiff", outdirmaxch+"_corrected/"+tempimage);
			close();
			File.delete(tempdir + tempimage);
			File.delete(tempdir + "out/" + tempimage);
			}
		close("*");
		//open all corrected images to be used for the stitching
		for (k=0; k<stitch_channel.length; k++){
			open(outdirmax + "_" + stitch_channel[k] + "/_corrected/" + stitch_channel[k] + "nm_MAX_corr_"+replace(infiles[i], ".ims", ".tif"));
			setMinAndMax(0, 65535);
			}
		if (stitch_channel.length > 1){
			run("Images to Stack", "use");
			run("Z Project...", "projection=[Max Intensity]");
			}	
		saveAs("Tiff", stitchdir + String.join(stitch_channel, "_") + "nm_MAX_corr_"+replace(infiles[i], ".ims", ".tif"));
		close("*");
		} else {
			print("skipped "+infiles[i]);
			}
	}

File.append("Finished correction for all files.", logfile);

//extract index of first image (..._F????.tif)
maxlist = getFileList(stitchdir);
filenm = maxlist[0];
init = split(maxlist[0], "_");
init = init[init.length-1];
init = replace(init, "F", "");
init = replace(init, ".tif", "");
init = parseInt(init);

filenm = replace(filenm , "[0-9]{4}.tif", "\\{iiii\\}.tif");
filenm = replace(filenm , "[0-9]{3}.tif", "\\{iii\\}.tif");
filenm = replace(filenm , "[0-9]{2}.tif", "\\{ii\\}.tif");
filenm = replace(filenm , "[0-9]{1}.tif", "\\{i\\}.tif");

//run stitching on selected channel (computing perfect overlap)
outdirmaxstitch = outdirmax + "/_stitch/";
run("Grid/Collection stitching", "type=[Grid: snake by columns] order=[Up & Right] grid_size_x=x_grid grid_size_y=y_grid tile_overlap=o first_file_index_i=init directory=" + outdirmaxstitch + " file_names=" + filenm + " output_textfile_name=TileConfiguration.txt fusion_method=[Do not fuse images (only write TileConfiguration)] regression_threshold=0.30 max/avg_displacement_threshold=2.5 absolute_displacement_threshold=3.5 compute_overlap subpixel_accuracy computation_parameters=[Save computation time (but use more RAM)] image_output=[Fuse and display]");

//modify file names in the output tile configuration file for each channel
lns = split(File.openAsString(outdirmaxstitch + "TileConfiguration.registered.txt"), "\n");

//in uncorrected maximum projection folder (stack with all colors)
outfile = outdirmax + "TileConfiguration.registered.txt";
if (File.exists(outfile)){
	File.delete(outfile);
	}
for (k=0; k<lns.length; k++){
	if (startsWith(lns[k], String.join(stitch_channel, "_"))){
		lns[k] = replace(lns[k], String.join(stitch_channel, "_") + "nm_MAX_corr", "MAX");
		File.append(lns[k], outfile); 
	} else {
		File.append(lns[k], outfile);
		}
}

for (j=0; j<wavelengths.length; j++){
	//in uncorrected maximum projection folder (each color)
	outdirmaxch = outdirmax + "_" + wavelengths[j] + "/";
	outfile2 = outdirmaxch + "TileConfiguration.registered.txt";
	if (File.exists(outfile2)){
		File.delete(outfile2);
		}
	temp_lns = Array.copy(lns);
	for (k=0; k<temp_lns.length; k++){
		if (startsWith(temp_lns[k], "MAX")){
			temp_lns[k] = replace(temp_lns[k], "MAX", wavelengths[j] + "nm_MAX");
			File.append(temp_lns[k], outfile2);
			} else {
				File.append(temp_lns[k], outfile2);
				}
		}
	//in corrected maximum projection folder (if correction was selected)
	if (correct[j]==0){
		continue;
		}
	outdirmaxchcorr = outdirmaxch + "_corrected/";
	outfile3 = outdirmaxchcorr + "TileConfiguration.registered.txt";
	if (File.exists(outfile3)){
		File.delete(outfile3);
		}
	temp_lns = Array.copy(lns);
	for (k=0; k<temp_lns.length; k++){
		if (startsWith(temp_lns[k], "MAX")){
			temp_lns[k] = replace(temp_lns[k], "MAX", wavelengths[j] + "nm_MAX_corr");
			File.append(temp_lns[k], outfile3);
			} else {
				File.append(temp_lns[k], outfile3);
				}
		}
	}

//apply stitch positions to uncorrected and (if applicable) corrected single-color images
filenm = replace(filenm, String.join(stitch_channel, "_") + "nm_MAX_corr", "MAX");
filenm = replace(filenm, "_F\\{i{1,4}\\}.tif", "_Fused_");
for (j=0; j<wavelengths.length; j++){
	outdirmaxch = outdirmax + "_" + wavelengths[j] + "/";
	outdirmaxchcorr = outdirmaxch + "_corrected/";
	run("Grid/Collection stitching", "type=[Positions from file] order=[Defined by TileConfiguration] directory=" + outdirmaxch + " layout_file=TileConfiguration.registered.txt fusion_method=[Linear Blending] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 subpixel_accuracy computation_parameters=[Save computation time (but use more RAM)] image_output=[Fuse and display]");
	setMinAndMax(0, 65535);
	saveAs("Tiff", fused+filenm+wavelengths[j]+"nm.tif");
	if (correct[j]==0){
		continue;
		}
	run("Grid/Collection stitching", "type=[Positions from file] order=[Defined by TileConfiguration] directory=" + outdirmaxchcorr + " layout_file=TileConfiguration.registered.txt fusion_method=[Linear Blending] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50 subpixel_accuracy computation_parameters=[Save computation time (but use more RAM)] image_output=[Fuse and display]");
	setMinAndMax(0, 65535);
	saveAs("Tiff", fused+filenm+wavelengths[j]+"nm_corr.tif");
	}

//Finish it off
close("*");
run("Collect Garbage");
File.append("Finished " + subdir, logfile);
File.append("Finished run at:\n" + GetTimeString(), logfile);