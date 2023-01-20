script_folder = "$baseDir/bin"

process collect_data{

    memory { 1.GB }
    time '1h'
    
    publishDir "$params.output_path", mode:'copy', overwrite: true

    input:
		val(input_path)
	
    output:
        path("sample_metadata.csv", emit: metadata_csv)
    
    script:
    """
	echo "sample,dapi,counts" > sample_metadata.csv
	while IFS= read -d \$'\\0' -r DAPI
	do
		SAMPLE="\${DAPI##$input_path/Panorama_}"
		SAMPLE="\${SAMPLE%%_Channel3_R8_.tiff}"
		COUNTS="$input_path/Panorama_""\$SAMPLE""_results_withFP.txt"
		echo "\$SAMPLE,\$DAPI,\$COUNTS" >> sample_metadata.csv 
	done < <(find "$input_path/" -name "*_Channel3_R8_.tiff" -print0)
    """
}

process fill_image_gaps{

    memory { 8.GB * task.attempt }
    time '1h'

    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = { workflow.profile.contains("gpu") ? 
		"library://michelebortol/resolve_tools/toolbox:gpu" : "library://michelebortol/resolve_tools/toolbox:latest" }

    input:
		val(sample_name)
		path(dapi_path)
	
    output:
        path("$sample_name-gridfilled.tiff", emit: filled_image)

    script:
    """
	python3.8 -u /MindaGap/mindagap.py $dapi_path 3 > gapfilling_log.txt
	mv *gridfilled.tif* $sample_name-gridfilled.tiff 2>&1

    """
}

process deduplicate{

    memory { 8.GB * task.attempt }
    time '1h'

    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = { workflow.profile.contains("gpu") ? 
		"library://michelebortol/resolve_tools/toolbox:gpu" : "library://michelebortol/resolve_tools/toolbox:latest" }

    input:
		val(sample_name)
		path(transcript_path)
        val(tile_size)
        val(window_size)
        val(max_freq)
        val(min_mode)
	
    output:
        path("$sample_name-filtered_transcripts.txt", emit: filtered_transcripts)

    script:
    """
	python3.8 -u /MindaGap/duplicate_finder.py $transcript_path $tile_size $window_size \
      $max_freq $min_mode > deduplication_log.txt
	mv *_markedDups.txt $sample_name-filtered_transcripts.txt 2>&1

    """
}

process cellpose_segment{
    
    memory { 8.GB * task.attempt }
    time '72h'
    
    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 4 

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = { workflow.profile.contains("gpu") ? 
		"library://michelebortol/resolve_tools/toolbox:gpu" : "library://michelebortol/resolve_tools/toolbox:latest" }

    input:
		val(sample_name)
		val(model_name)
		val(probability)
		val(diameter)
		path(dapi_path)
	
    output:
        path("$sample_name-cellpose_mask.tiff", emit: mask_image)

    script:
	def use_gpu = workflow.profile.contains("gpu") ? "--gpu" : ""
    """
	python3.8 -u $script_folder/cellpose_segmenter.py $dapi_path $model_name $probability \
		$diameter $sample_name-cellpose_mask.tiff $use_gpu > $sample_name-segmentation_log.txt 2>&1
    """
}

process mesmer_segment{
    
    memory { 8.GB * task.attempt }
    time '72h'
    
    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 4

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = { workflow.profile.contains("gpu") ? 
		"library://michelebortol/resolve_tools/toolbox:gpu" : "library://michelebortol/resolve_tools/toolbox:latest" }

    input:
		val(sample_name)
		path(dapi_path)
		val(maxima_threshold)          
		val(maxima_smooth)            
		val(interior_threshold)      
		val(interior_smooth)        
		val(small_objects_threshold)   
		val(fill_holes_threshold)  
		val(radius)                    
	
    output:
        path("$sample_name-mesmer_mask.tiff", emit: mask_image)

    script:
    """
	python3.8 -u $script_folder/mesmer_segmenter.py $dapi_path \
        $sample_name-mesmer_mask.tiff --maxima_threshold $maxima_threshold\
		--maxima_smooth $maxima_smooth --interior_threshold $interior_threshold \
		--interior_smooth $interior_smooth --small_objects_threshold $small_objects_threshold \
		--fill_holes_threshold $fill_holes_threshold --radius $radius \
		> $sample_name-segmentation_log.txt 2>&1
    """
}


process make_rois{
    
    memory { 8.GB * task.attempt }
    time '72h'
    
    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 4

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = { workflow.profile.contains("gpu") ? 
		"library://michelebortol/resolve_tools/toolbox:gpu" : "library://michelebortol/resolve_tools/toolbox:latest" }

    input:
		val(sample_name)
		path(mask_path)
	
    output:
        path("$sample_name-roi.zip", emit: roi_zip)
    
	script:
    
	"""
	python3.8 -u $script_folder/roi_maker.py $mask_path \
		$sample_name-roi.zip > $sample_name-roi-log.txt 2>&1
    """
}

process extract_sc_data{

    memory { 8.GB * task.attempt }
    time '72h'

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = { workflow.profile.contains("gpu") ? 
		"library://michelebortol/resolve_tools/toolbox:gpu" : "library://michelebortol/resolve_tools/toolbox:latest" }

    input:
        val(sample_name)
		path(mask_image_path)
		path(transcript_coord_path)

    output:
        path("$sample_name-cell_data.csv", emit: sc_data)

    script:

    """
	python3.8 $script_folder/extracter.py $mask_image_path $transcript_coord_path \
		${sample_name}-cell_data.csv > $sample_name-extraction_log.txt 2>&1
    """
}

