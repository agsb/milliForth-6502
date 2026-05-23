#!/usr/bin/perl
# take a binary input file and convert to CEGMON monitor format
# for loading into a "Grant Searle" style 6502.
# $1 is the input file (minus .out)
open my $fn = $ARGV[$#ARGV].'.out';
open my $fn2 = $ARGV[$#ARGV].'.mon';
open my $fh, '<:raw', $fn or die "can't open file $fn\n";
open my $fh2, '>', $fn2 or die "can't open file $fn2\n";
my $done =0;
my $base=0x0400; # Where to load the code. 6502 is not relocatable. Re-assemble first!
printf $fh2 (".%04X",$base);
my $bytes_read;
my $bytes;
while (!$done) {
  $bytes_read = read $fh, $byte, 1; # read one char
  unless ($bytes_read == 1) {
    $done =1;
    die 'Got $bytes_read but expected 1' unless ($bytes_read == 0);
  }
  my $c=ord($byte);
  #printf $fh2 (".%04X",$base);
  printf $fh2 ("%02X\n",$c);
  $base+=$bytes_read;
}
close $fh2;
close $fh1;
