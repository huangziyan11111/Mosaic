ruleorder: trim_adapters_quality_illumina_PE > trim_adapters_quality_illumina_SE 
#ruleorder: listContaminants_PE > listContaminants_SE 
#ruleorder: removeContaminants_PE > removeContaminants_SE 
ruleorder: subsampleReadsIllumina_PE > subsampleReadsIllumina_SE 
ruleorder: normalizeReads_PE > normalizeReads_SE 
ruleorder: postQualityCheckIlluminaPE > postQualityCheckIlluminaSE


rule qualityCheckIllumina:
	input:
		raw_fastq=dirs_dict["RAW_DATA_DIR"]+"/{sample}_{reads}.fastq"
	output:
		html=temp(dirs_dict["RAW_DATA_DIR"] + "/{sample}_{reads}_fastqc.html"),
		zipped=temp(dirs_dict["RAW_DATA_DIR"] + "/{sample}_{reads}_fastqc.zip")
	message: 
		"Performing fastqQC statistics"
	conda:
		dirs_dict["ENVS_DIR"] + "/QC.yaml"
#	threads: 1
	shell:
		"""
		fastqc {input}
		"""
rule qualityCheckNanopore:
	input:
		raw_fastq=dirs_dict["RAW_DATA_DIR"]+"/{sample_nanopore}_nanopore.fastq"
	output:
		nanoqc_dir=temp(directory(dirs_dict["RAW_DATA_DIR"] + "/{sample_nanopore}_nanoplot")),
		nanoqc=dirs_dict["QC_DIR"] + "/{sample_nanopore}_nanopore_report_preQC.html"
	message: 
		"Performing nanoQC statistics"
	conda:
		dirs_dict["ENVS_DIR"] + "/env3.yaml"
#	threads: 1
	shell:
		"""
		nanoQC -o {output.nanoqc_dir} {input.raw_fastq}
		mv {output.nanoqc_dir}/nanoQC.html {output.nanoqc}
		"""

rule multiQC:
	input:
		html=expand(dirs_dict["RAW_DATA_DIR"]+"/{sample}_{reads}_fastqc.html", sample=SAMPLES, reads=READ_TYPES),
		zipped=expand(dirs_dict["RAW_DATA_DIR"] + "/{sample}_{reads}_fastqc.zip", sample=SAMPLES, reads=READ_TYPES)
	output:
		multiqc=dirs_dict["QC_DIR"]+ "/preQC_multiqc_report.html"
	params:
		fastqc_dir=dirs_dict["RAW_DATA_DIR"],
		html_name="preQC_multiqc_report.html",
		multiqc_dir=dirs_dict["QC_DIR"]
	message: 
		"Generating MultiQC report"
	conda:
		dirs_dict["ENVS_DIR"]+ "/QC.yaml"
	shell:
		"""
		multiqc {params.fastqc_dir} -o {params.multiqc_dir} -n {params.html_name}
		"""
		
rule trim_adapters_quality_illumina_PE:
	input:
		forward=dirs_dict["RAW_DATA_DIR"] + "/{sample}_" + config['forward_tag'] + ".fastq",
		reverse=dirs_dict["RAW_DATA_DIR"] + "/{sample}_" + config['reverse_tag'] + ".fastq",
		qc_report=dirs_dict["QC_DIR"]+ "/preQC_multiqc_report.html"
	output:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired.fastq"),
		forward_unpaired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_unpaired.fastq"),
		reverse_unpaired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_unpaired.fastq")
	params:
		adapters=dirs_dict["ADAPTERS_DIR"] + "/" + config['adapters_file']
	message: 
		"Trimming Illumina Adapters with Trimmomatic"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	threads: 2
	shell:
		"""
		trimmomatic PE -threads {threads} -phred33 {input.forward} {input.reverse} \
		{output.forward_paired} {output.forward_unpaired} {output.reverse_paired} {output.reverse_unpaired} \
		ILLUMINACLIP:{params.adapters}:2:30:10 LEADING:{config[trimmomatic_leading]} TRAILING:{config[trimmomatic_trailing]} \
		SLIDINGWINDOW:{config[trimmomatic_window_size]}:{config[trimmomatic_window_quality]} MINLEN:{config[trimmomatic_minlen]}
		"""

rule trim_adapters_quality_illumina_SE:
	input:
		forward=dirs_dict["RAW_DATA_DIR"] + "/{sample}_" + config['forward_tag'] + ".fastq",
		qc_report=dirs_dict["QC_DIR"]+ "/pre_processing_multiqc_report.html"
	output:
		forward_unpaired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_unpaired.fastq"),
	params:
		adapters=dirs_dict["ADAPTERS_DIR"] + "/" + config['adapters_file']
	message: 
		"Trimming Illumina Adapters with Trimmomatic"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	threads: 2
	shell:
		"""
		trimmomatic SE -threads {threads} -phred33 {input.forward} {output.forward_unpaired} \
		ILLUMINACLIP:{params.adapters}:2:30:10 LEADING:{config[trimmomatic_leading]} TRAILING:{config[trimmomatic_trailing]} \
		SLIDINGWINDOW:{config[trimmomatic_window_size]}:{config[trimmomatic_window_quality]} MINLEN:{config[trimmomatic_minlen]}
		"""

rule remove_adapters_quality_nanopore:
	input:
		raw_data=dirs_dict["RAW_DATA_DIR"] + "/{sample_nanopore}_nanopore.fastq",
		nanoqc=dirs_dict["QC_DIR"] + "/{sample_nanopore}_nanopore_report.html"
	output:
		fastq=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.fastq"),
		porechopped=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_porechopped.fastq"),
		#size=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.txt"
	message: 
		"Trimming Nanopore Adapters with Porechop"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env3.yaml"
	threads: 2
	shell:
		"""
		porechop -i {input.raw_data} -o {output.porechopped} --threads {threads}
		NanoFilt -q 10 -l 1000 --headcrop 50 {output.porechopped} > {output.fastq}
		#grep -c "^@" fastq > {output} size
		"""

rule getContaminants:
	output:
		contaminant_fasta=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.fasta",
		contaminant_bitmask=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.bitmask",
		contaminant_srprism=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.srprism.ss",
		contaminant_blastdb=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.fasta.nhr",
	message: 
		"Downloading contaminant genomes"
	params:
		contaminants_dir=dirs_dict["CONTAMINANTS_DIR"]
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	resources:
		mem_mb=32000
	shell:
		"""
		wget $(esearch -db "assembly" -query {wildcards.contaminant} | esummary | xtract -pattern DocumentSummary -element FtpPath_RefSeq | awk -F"/" '{{print $0"/"$NF"_genomic.fna.gz"}}')
		gunzip -f *{wildcards.contaminant}*gz
		cat *{wildcards.contaminant}*fna >> {output.contaminant_fasta}
		rm *{wildcards.contaminant}*fna
		bmtool -d {output.contaminant_fasta} -o {output.contaminant_bitmask}  -w 18 -z
		srprism mkindex -i {output.contaminant_fasta} -o {output.contaminant_srprism} -M {resources.mem_mb}
		makeblastdb -in {output.contaminant_fasta} -dbtype nucl
		"""

rule listContaminants_PE:
	input:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired.fastq"),
		forward_unpaired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_unpaired.fastq"),
		reverse_unpaired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_unpaired.fastq"),
		contaminant_fasta=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.fasta",
		contaminant_bitmask=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.bitmask",
		contaminant_srprism=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.srprism",
		contaminant_blastdb=dirs_dict["CONTAMINANTS_DIR"] +"/{contaminant}.fasta.nhr",
	output:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}-{contaminant}-forward_paired.tot.txt"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}-{contaminant}-reverse_paired.tot.txt"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}-{contaminant}-unpaired.tot.txt",
		singletons=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}-{contaminant}-singletons.tot.txt",
		bmtagger_dir=directory(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}-{contaminant}-BMTagger"),
		temp_dir=directory(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}-{contaminant}_temp")
	message: 
		"Removing contaminants with BMTagger"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	threads: 1
	resources:
		mem_mb=48000
	shell:
		"""
		#PE
		#paired
		bmtagger.sh -b {input.contaminant_bitmask} -x {input.contaminant_srprism} -T {output.temp_dir} -q 1 \
		-1 {input.forward_paired} -2 {input.reverse_paired}-o {output.bmtagger_dir} -X
		"""

# rule listContaminants_SE:
# 	input:
# 		forward_unpaired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_unpaired.fastq"),
# 		contaminants_fasta=dirs_dict["CONTAMINANTS_DIR"] +"/contaminants.fasta"
# 	output:
# 		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.fastq",
# 		unpaired_size=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.txt"
# 	message: 
# 		"Removing contaminants with BBtools"
# 	conda:
# 		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
# 	threads: 1
# 	resources:
# 		mem_mb=4000
# 	shell:
# 		"""
# 		#SE
# 		bbduk.sh -Xmx{resources.mem_mb}m in={input.forward_unpaired} out={output.unpaired} ref={input.contaminants_fasta} k=31 hdist=1 threads={threads} 
# 		grep -c "^@" {output.unpaired} > {output.unpaired_size}
# 		"""


rule removeContaminants_PE:
	input:
		forward_paired=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{{sample}}-{contaminant}-forward_paired.tot.txt", contaminant=CONTAMINANTS),
		reverse_paired=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{{sample}}-{contaminant}-reverse_paired.tot.txt", contaminant=CONTAMINANTS),
		unpaired=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{{sample}}-{contaminant}-unpaired.tot.txt", contaminant=CONTAMINANTS),
		singletons=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{{sample}}-{contaminant}-singletons.tot.txt", contaminant=CONTAMINANTS),
	output:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.tot.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.tot.fastq"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.fastq",
	message: 
		"Removing contaminants with BMTagger"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	threads: 1
	resources:
		mem_mb=48000
	shell:
		"""
		#PE
		#paired
		bmtagger.sh -b {input.contaminant_bitmask} -x {input.contaminant_srprism} -T {output.temp_dir} -q 1 \
		-1 {input.forward_paired} -2 {input.reverse_paired}-o {output.bmtagger_dir} -X
		"""


rule postQualityCheckIlluminaPE:
	input:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.tot.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.tot.fastq"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.fastq",	
	output:
		html_forward=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.tot_fastqc.html"),
		zipped_forward=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.tot_fastqc.zip"),
		html_reverse=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.tot_fastqc.html"),
		zipped_reverse=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.tot_fastqc.zip"),
		html_unpaired=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot_fastqc.html"),
		zipped_unpaired=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot_fastqc.zip"),
	message: 
		"Performing fastqQC statistics"
	conda:
		dirs_dict["ENVS_DIR"] + "/QC.yaml"
#	threads: 1
	shell:
		"""
		fastqc {input.forward_paired}
		fastqc {input.reverse_paired}
		fastqc {input.unpaired}
		"""

rule postQualityCheckIlluminaSE:
	input:
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.fastq",
	output:
		html=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot_fastqc.html"),
		zipped=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot_fastqc.zip")
	message: 
		"Performing fastqQC statistics"
	conda:
		dirs_dict["ENVS_DIR"] + "/QC.yaml"
#	threads: 1
	shell:
		"""
		fastqc {input}
		"""

rule postQualityCheckNanopore:
	input:
		fastq=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.fastq"),
	output:
		nanoqc_dir=temp(directory(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanoplot_post")),
		nanoqc=dirs_dict["QC_DIR"] + "/{sample_nanopore}_nanopore_report_postQC.html"
	message: 
		"Performing nanoQC statistics"
	conda:
		dirs_dict["ENVS_DIR"] + "/env3.yaml"
#	threads: 1
	shell:
		"""
		nanoQC -o {output.nanoqc_dir} {input.fastq}
		mv {output.nanoqc_dir}/nanoQC.html {output.nanoqc}
		"""

rule postMultiQC:
	input:
		html=expand(dirs_dict["CLEAN_DATA_DIR"]+"/{sample}_unpaired_clean.tot_fastqc.html", sample=SAMPLES),
		zipped=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot_fastqc.zip", sample=SAMPLES)
	output:
		multiqc=dirs_dict["QC_DIR"]+ "/postQC_multiqc_report.html"
	params:
		fastqc_dir=dirs_dict["CLEAN_DATA_DIR"],
		html_name="postQC_multiqc_report.html",
		multiqc_dir=dirs_dict["QC_DIR"]
	message: 
		"Generating MultiQC report"
	conda:
		dirs_dict["ENVS_DIR"]+ "/QC.yaml"
	shell:
		"""
		multiqc {params.fastqc_dir} -o {params.multiqc_dir} -n {params.html_name}
		"""
rule subsampleReadsIllumina_PE:
	input:
		unpaired_sizes=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.txt", sample=SAMPLES),
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.tot.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.tot.fastq"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.fastq"
	output:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.sub.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.sub.fastq"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.sub.fastq",
		paired_size=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_paired_clean.sub.txt"),
		unpaired_size=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.sub.txt"
	message: 
		"Subsampling Illumina reads with BBtools"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	params: 
		max_subsample=int(int(config['max_subsample'])/2),
		files_unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/*_unpaired_clean.tot.txt",
		files_paired=dirs_dict["CLEAN_DATA_DIR"] + "/*_paired_clean.tot.txt"
	threads: 1
	resources:
		mem_mb=4000
	shell:
		"""
		#paired
		paired=$( cat {params.files_paired} | sort -n | head -1 )
		p=$([ $paired -le {params.max_subsample} ] && echo "$paired" || echo {params.max_subsample})
		reformat.sh in1={input.forward_paired} in2={input.reverse_paired} out1={output.forward_paired} out2={output.reverse_paired} reads=$p
		#unpaired
		unpaired_temp=$( cat {params.files_unpaired} | sort -n | head -1 )
		un=$([ $unpaired_temp -le {params.max_subsample} ] && echo "$unpaired_temp" || echo {params.max_subsample})
		reads_left=$(({params.max_subsample} - ($paired*2)))
		unpaired=$([ $un -le $reads_left ] && echo "$un" || echo $reads_left )
		reformat.sh in={input.unpaired} out={output.unpaired} reads=$unpaired
		grep -c "^@" {output.unpaired} > {output.unpaired_size}
		grep -c "^@" {output.forward_paired} > {output.paired_size}
		"""

rule subsampleReadsIllumina_SE:
	input:
		unpaired_sizes=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.txt", sample=SAMPLES),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.tot.fastq"
	output:
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.sub.fastq",
		unpaired_size=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.sub.txt"
	message: 
		"Subsampling Illumina reads with BBtools"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	params: 
		max_subsample=config['max_subsample'],
		files_unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/*_unpaired_clean.tot.txt"
	threads: 1
	resources:
		mem_mb=4000
	shell:
		"""
		#unpairedte
		unpaired_temp=$( cat {params.files_unpaired} | sort -n | head -1 )
		echo $unpaired_temp
		un=$([ $unpaired_temp -le {params.max_subsample} ] && echo "$unpaired_temp" || echo {params.max_subsample})
		echo $un
		reformat.sh in={input.unpaired} out={output.unpaired} reads=$un
		grep -c "^@" {output.unpaired} > {output.unpaired_size}
		"""

rule subsampleReadsNanopore:
	input:
		nano_sizes=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.txt", sample_nanopore=NANOPORE_SAMPLES),
		nanopore=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.fastq",
	output:
		nanopore=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.sub.fastq",
		size=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.sub.txt",
	message: 
		"Subsampling Nanopore reads with BBtools"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	params: 
		min_depth=config['min_norm'],
		max_depth=config['max_norm'],
		sizes=dirs_dict["CLEAN_DATA_DIR"] + "/*_nanopore_clean.tot.txt"
	threads: 1
	resources:
		mem_mb=4000
	shell:
		"""
		nanopore=$( cat {params.sizes} | sort -n | head -1 )
		reformat.sh in={input.nanopore} out={output.nanopore} reads=$nanopore
		grep -c "^@" {output.nanopore} > {output.size}
		"""

rule normalizeReads_PE:
	input:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.{sampling}.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.{sampling}.fastq"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.{sampling}.fastq",
	output:
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_norm.{sampling}.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_norm.{sampling}.fastq"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_norm.{sampling}.fastq",
	message: 
		"Normalizing reads with BBtools"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	params: 
		min_depth=config['min_norm'],
		max_depth=config['max_norm']
	threads: 4
	resources:
		mem_mb=6000
	shell:
		"""
		#PE
		#paired
		bbnorm.sh -Xmx{resources.mem_mb}m ecc in1={input.forward_paired} in2={input.reverse_paired} out1={output.forward_paired} out2={output.reverse_paired} \
		target={params.max_depth} mindepth={params.min_depth} t={threads}
		#unpaired
		bbnorm.sh -Xmx{resources.mem_mb}m ecc in={input.unpaired} out={output.unpaired} target={params.max_depth} mindepth={params.min_depth}		
		"""

rule normalizeReads_SE:
	input:
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.{sampling}.fastq"
	output:
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_norm.{sampling}.fastq"
	message: 
		"Normalizing reads with BBtools"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	params: 
		min_depth=config['min_norm'],
		max_depth=config['max_norm']
	threads: 4
	resources:
		mem_mb=6000
	shell:
		"""
		#SE
		#unpaired
		bbnorm.sh -Xmx{resources.mem_mb}m ecc in={input.unpaired} out={output.unpaired} target={params.max_depth} mindepth={params.min_depth} t={threads}	
		"""

