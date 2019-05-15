

rule getAbundancesPE:
	input:
		cov_final=expand(dirs_dict["MAPPING_DIR"]+ "/{sample}_{{confidence}}_confidence_filtered_coverage.{{sampling}}.txt", sample=SAMPLES),
		tpmean=expand(dirs_dict["MAPPING_DIR"]+ "/{sample}_{{confidence}}_confidence_tpmean.{{sampling}}.tsv", sample=SAMPLES),
		unpaired_size=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.sub.txt", sample=SAMPLES),
		paired_size=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_paired_clean.sub.txt", sample=SAMPLES),
	output:
		abundances=dirs_dict["MAPPING_DIR"]+ "/{confidence}_confidence_vOTU_abundance_table.{sampling}.txt",
	message:
		"Getting vOTU tables"
	threads: 1
	shell:
		"""
		touch {output.abundances}
		"""
rule getAbundancesSE:	
	input:
		cov_final=expand(dirs_dict["MAPPING_DIR"]+ "/{sample}_{{confidence}}_confidence_filtered_coverage.{{sampling}}.txt", sample=SAMPLES),
		tpmean=expand(dirs_dict["MAPPING_DIR"]+ "/{sample}_{{confidence}}_confidence_tpmean.{{sampling}}.tsv", sample=SAMPLES),
		unpaired_size=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.sub.txt", sample=SAMPLES),
	output:
		abundances=dirs_dict["MAPPING_DIR"]+ "/{confidence}_confidence_vOTU_abundance_table.{sampling}.txt",
	message:
		"Getting vOTU tables"
	threads: 1
	shell:
		"""
		touch {output.abundances}
		"""
rule tabletoBIOM:
	input:
		abundances=dirs_dict["MAPPING_DIR"]+ "/{confidence}_confidence_vOTU_abundance_table.{sampling}.txt",
	output:
		abundances=dirs_dict["MAPPING_DIR"]+ "/{confidence}_confidence_vOTU_abundance_table.{sampling}.biom",
	message:
		"Getting vOTU tables"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		touch {output.abundances}
		"""
rule getSummaryTable:
	input:
		hmm_results=dirs_dict["VIRAL_DIR"]+ "/hmm_parsed.{sampling}.out",
		pvalues = dirs_dict["VIRAL_DIR"] + "/virFinder_pvalues.{sampling}.txt",
		categories=dirs_dict["VIRAL_DIR"] + "/virSorter_{sampling}/VIRSorter_global-phage-signal.csv",
		high_dir=(dirs_dict["VIRAL_DIR"]+ "/high_confidence_vContact.{sampling}"),
		low_dir=(dirs_dict["VIRAL_DIR"]+ "/low_confidence_vContact.{sampling}"),
		representative_lenghts=dirs_dict["vOUT_DIR"] + "/representative_lengths.{sampling}.txt"
	output:
		summary=dirs_dict["MAPPING_DIR"]+ "/vOTU_summary.{sampling}.txt",
	message:
		"Getting vOTU tables"
	threads: 1
	shell:
		"""
		touch {output.summary}
		"""