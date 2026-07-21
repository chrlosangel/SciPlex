BEGIN {
    NO_sgRNA = "NO_SGRNA";
    NO_GENE = "NO_GENE";
    read_num = 0;
    hits = 0;

    bases[1] = "A";
    bases[2] = "C";
    bases[3] = "G";
    bases[4] = "T";
    
    print "[DEBUG] Initializing sgRNA lookup table..."
}

# Read the sgRNA file and generate a lookup table where sequence is the key
{
    if (ARGIND == 1) {
        sgRNA_seq[$2] = $1;


        for (i = 1; i <= length($2); i++) {
            for (j = 1; j <= 4; j++) {
                mismatch = "";
                if (i > 1)
                    mismatch = mismatch substr($2, 1, i - 1);
                mismatch = mismatch bases[j];
                if (i < length($2))
                    mismatch = mismatch substr($2, i + 1, length($2) - i);
                
                if (!(mismatch in sgRNA_seq)) {
                    sgRNA_seq[mismatch] = $1;
                }
            }
        }
    }

    else {  
        # Processing the FASTQ file (starting from second argument)
        read_num++;
        header = $0;

        # Read the next line (sequence line)
        if (getline seq <= 0) {
            print "[ERROR] Failed to read sequence line!" #> "/tmp/debug_fastq.txt";
            exit 1;
        }

        # Read the '+' line
        if (getline plus_line <= 0) {
            print "[ERROR] Failed to read '+' line!";
            exit 1;
        }

        # Read quality score line
        if (getline qual <= 0) {
            print "[ERROR] Failed to read quality line!";
            exit 1;
        }


        # Extract sgRNA sequences
        sgRNA = substr(seq, 24, 20);
        sgRNA_2 = substr(seq, 23, 20);
        sgRNA_3 = substr(seq, 25, 20);
        sgRNA_4 = substr(seq, 22, 20);
        sgRNA_5 = substr(seq, 26, 20);

        if (sgRNA in sgRNA_seq) {
            found_gene = sgRNA_seq[sgRNA];
            header = header "|" sgRNA "|" found_gene;
        } else if (sgRNA_2 in sgRNA_seq){
            found_gene = sgRNA_seq[sgRNA_2];
            header = header "|" sgRNA_2 "|" found_gene;
        } else if (sgRNA_3 in sgRNA_seq){
            found_gene = sgRNA_seq[sgRNA_3];
            header = header "|" sgRNA_3 "|" found_gene;
        } else if (sgRNA_4 in sgRNA_seq){
            found_gene = sgRNA_seq[sgRNA_4];
            header = header "|" sgRNA_4 "|" found_gene;
        } else if (sgRNA_5 in sgRNA_seq){
            found_gene = sgRNA_seq[sgRNA_5];
            header = header "|" sgRNA_5 "|" found_gene;
        }
        else {
            header = header "|" sgRNA "|" "NA_NA";
        }
        
        print header;
        #printf "%s\n", seq;
        #if (getline > 0) printf "+\n";
        #if (getline qual > 0) printf "%s\n", qual;
    }
}

END {
    print "[DEBUG] Completed processing all reads." #> "/tmp/debug_fastq.txt";
}