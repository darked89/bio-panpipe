# *- bash -*

# INCLUDE BASH LIBRARY
. ${bindir}/bam_utils_lib.sh

########
print_desc()
{
    echo "gen_bed_for_genome generated bed file for whole genome"
    echo "type \"gen_bed_for_genome --help\" to get usage information"
}

########
usage()
{
    echo "gen_bed_for_genome   -r <string> -o <string>"
    echo "                     [--help]"
    echo ""
    echo "-r <string>          File with reference genome"
    echo "-o <string>          Prefix of output files"
    echo "--help               Display this help and exit"
}

########
read_pars()
{
    r_given=0
    o_given=0
    while [ $# -ne 0 ]; do
        case $1 in
            "--help") usage
                      exit 1
                      ;;
            "--version") version
                         exit 1
                         ;;
            "-r") shift
                  if [ $# -ne 0 ]; then
                      ref=$1
                      r_given=1
                  fi
                  ;;
            "-o") shift
                  if [ $# -ne 0 ]; then
                      outpref=$1
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
        if [ ! -f ${ref} ]; then
            echo "Error! file ${ref} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${o_given} -eq 0 ]; then
        echo "Error! -o parameter not given!" >&2
        exit 1
    fi
}

########
print_pars()
{
    if [ ${r_given} -eq 1 ]; then
        echo "-r is ${ref}" >&2
    fi

    if [ ${o_given} -eq 1 ]; then
        echo "-o is ${outpref}" >&2
    fi
}

########
process_pars()
{
    conda activate base || exit 1

    samtools faidx ${ref}

    $AWK '{print $1 "\t0\t" $2}' ${ref}.fai > ${outpref}.bed
    
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
