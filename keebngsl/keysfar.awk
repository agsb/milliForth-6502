
BEGIN {

    FS=" "

    // keyboard layout effort 
    // file with "weight char char char ... char"

    file = ARGV[1]

    while ((getline < file) > 0) {
    
        if (!(/^#/)) {

            w = $1 + 0

            for (i = 2; i <= NF; i++) {
                
                c = $i

                ws[c] = w ;

                }
            }
        }

    close (file)

    # don't use it as stdin

    delete ARGV[1]

    qss = 0
    pss = 0
    cvs = 0
}


{

        // line with "word ppm "

        if (/^#/) next

        m = split ($1, chars, "")

        for (i = 1; i <= m; i++) {
            
            c = chars[i]
            
            # count events 
            # ct[c] += 1
            
            # count effort event
            # cs[c] += ws[c]

            # count ppm events
            cv[c] += $2
            
            # count effort by ppm
            qs[c] += cv[c] * ws[c]

            # total ppm sum
            cvs += $2

            # total effort by ppm sum
            qss += cv[c] * ws[c]

            }
}

END {

    acs = 0
    print "# keys ppms ppm% eff% "
    for (c in cv) {
        printf (" %c %7ld %7.4lf %7.4lf\n", c, cv[c], cv[c]/cvs * 100.00, qs[c]/qss * 100.00)
        acs += qs[c]/qss * 100.00
        }
    print " = " acs

}
