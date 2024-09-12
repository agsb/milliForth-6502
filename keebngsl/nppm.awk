
BEGIN {

}


{

        // line with "word ... "

        if (/^#/) {
            print
            }
        else {
            
            v = int ($2/1000000.00)

            print $1 " " v

        }
}

END {


}
