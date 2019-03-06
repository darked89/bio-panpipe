# *- bash -*

########
print_desc()
{
    echo "add_contigs_to_genref add missing contigs listed in bam file to genome reference"
    echo "type \"add_contigs_to_genref --help\" to get usage information"
}

########
usage()
{
    echo "add_contigs_to_genref  -r <string> -b <string> [-c2a <string>]"
    echo "                       -o <string> [--help]"
    echo ""
    echo "-r <string>            File with reference genome"
    echo "-b <string>            bam file"
    echo "-c2a <string>          File containing a mapping between contig names and"
    echo "                       accession numbers"
    echo "-o <string>            Output directory"
    echo "--help                 Display this help and exit"
}

########
read_pars()
{
    r_given=0
    b_given=0
    c2a_given=0
    o_given=0
    while [ $# -ne 0 ]; do
        case $1 in
            "--help") usage
                      exit 1
                      ;;
            "-r") shift
                  if [ $# -ne 0 ]; then
                      baseref=$1
                      r_given=1
                  fi
                  ;;
            "-b") shift
                  if [ $# -ne 0 ]; then
                      bam=$1
                      b_given=1
                  fi
                  ;;
            "-c2a") shift
                  if [ $# -ne 0 ]; then
                      contig_to_acc=$1
                      c2a_given=1
                  fi
                  ;;
            "-o") shift
                  if [ $# -ne 0 ]; then
                      outd=$1
                      o_given=1
                  fi
                  ;;
        esac
        shift
    done   
}

########
check_pars()
{
    if [ ${r_given} -eq 0 ]; then   
        echo "Error! -r parameter not given!" >&2
        exit 1
    else
        if [ ! -f ${baseref} ]; then
            echo "Error! file ${baseref} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${b_given} -eq 0 ]; then   
        echo "Error! -b parameter not given!" >&2
        exit 1
    else
        if [ ! -f ${bam} ]; then
            echo "Error! file ${bam} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${c2a_given} -eq 1 ]; then   
        if [ ! -f ${contig_to_acc} ]; then
            echo "Error! file ${contig_to_acc} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${o_given} -eq 0 ]; then   
        echo "Error! -o parameter not given!" >&2
        exit 1
    else
        if [ ! -o ${outd} ]; then
            echo "Error! directory ${outd} does not exist" >&2
            exit 1
        fi
    fi
}

########
print_pars()
{
    if [ ${r_given} -eq 1 ]; then
        echo "-r is ${baseref}" >&2
    fi

    if [ ${b_given} -eq 1 ]; then
        echo "-b is ${bam}" >&2
    fi

    if [ ${c2a_given} -eq 1 ]; then
        echo "-c2a is ${contig_to_acc}" >&2
    fi

    if [ ${o_given} -eq 1 ]; then
        echo "-o is ${outd}" >&2
    fi
}

########
contig_in_list()
{
    local contig=$1
    local clist=$2

    while read c; do
        if [ "$contig" = "$c" ]; then
            return 0
        fi
    done < ${clist}

    return 1
}

########
get_missing_contig_names()
{
    local baseref=$1
    local bam=$2
    local outd=$3
            
    # Obtain reference contigs
    samtools faidx ${baseref}
    $AWK '{printf "%s\n",$1}' ${baseref}.fai > ${outd}/refcontigs

    # Obtain bam contigs
    samtools view -H $bam | $AWK '{if($1=="@SQ") print substr($2,4)}' > ${outd}/bamcontigs || exit 1

    while read bamcontigname; do
        if ! contig_in_list $bamcontigname ${outd}/refcontigs; then
            echo $bamcontigname
        fi
    done < ${outd}/bamcontigs    
}

########
contig_is_accession()
{
    local contig=$1

    if [[ $contig == *"."* ]]; then
        return 0
    else
        return 1
    fi
}

########
map_contig_to_acc_using_file()
{
    local contig_to_acc=$1
    local contig=$2

    while read entry; do
        local fields=($entry)
        local num_fields=${#fields[@]}
        if [ ${num_fields} -eq 2 ]; then
            if [ ${fields[0]} = $contig ]; then
                echo ${fields[1]}
                break
            fi
        fi
    done < ${contig_to_acc}
}

########
map_contig_to_accession()
{
    local contig_to_acc=$1
    local contig=$2

    if contig_is_accession ${contig}; then
        echo ${contig}
    else
        if [ ${contig_to_acc} != "${NOFILE}" ]; then
            map_contig_to_acc_using_file ${contig_to_acc} ${contig} || return 1
        fi
    fi
}

########
get_contigs()
{
    local contig_to_acc=$1
    local contiglist=$2

    while read contig; do
        local accession=`map_contig_to_accession ${contig_to_acc} ${contig}` || return 1
        if [ "$accession" = "" ]; then
            errmsg "Warning: contig $contig is not a valid accession nor there were mappings for it, skipping"
        else
            logmsg "Getting data for contig ${contig} (mapped to accession $accession)..."
            ${biopanpipe_bindir}/get_entrez_fasta -a ${accession} | ${SED} "s/${accession}/${contig}/"; pipe_fail || return 1
        fi
    done < ${contiglist}
}

########
process_pars()
{
    outfile=$outd/enriched_genref.fa
    
    # Copy base genome reference
    echo "* Copying base genome reference..." >&2
    cp $baseref $outfile || exit 1

    # Activate conda environment
    echo "* Activating conda environment..." >&2
    conda activate samtools || exit 1

    # Obtain list of missing contigs
    echo "* Obtaining list of missing contigs..." >&2
    get_missing_contig_names ${baseref} ${bam} ${outd} > ${outd}/missing_contigs.txt || exit 1

    # Enrich base reference
    echo "* Enriching base reference..." >&2
    get_contigs ${contig_to_acc} ${outd}/missing_contigs.txt >> $outfile || { errmsg "Error during FASTA data downloading"; exit 1; }

    # Index enriched reference
    echo "* Indexing enriched reference..." >&2
    samtools faidx ${outfile} || exit 1

    # Deactivate conda environment
    echo "* Deactivating conda environment..." >&2
    conda deactivate
}

########

if [ $# -eq 0 ]; then
    print_desc
    exit 1
fi

read_pars $@ || exit 1

check_pars || exit 1

print_pars || exit 1

process_pars || exit 1
