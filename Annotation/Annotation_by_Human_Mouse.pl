#!/usr/bin/perl -w
use strict;
use Data::Dumper;

die "perl $0 <m0><germline.fa><out><ref>\n" unless(@ARGV==4);


my $gene = $ARGV[4];
open I, "$ARGV[1]" or die;
my %fa_len;
my $all=0;

#--- read fa file	--------------
my %fa_seq;
while(<I>)
{
	chomp;
	s/^>//;
	my $id = $_;
	chomp(my $seq = <I>);
	$fa_len{$id} = length($seq);
	$all++;
	$fa_seq{$id} = $seq;
}
close I;

#-----	read reference file	-------------
my %ref_seq;
open I, "$ARGV[3]" or die;
while(<I>)
{
	chomp;
	s/^>//;
	my $id = $_;
	chomp(my $seq = <I>);
	$ref_seq{$id} = $seq;
}
close I;

#--------	read the alignment file		----------
my %back;
open I, "$ARGV[0]" or die;

open O, ">$ARGV[2]" or die;

print O "#Identity(%)\tdeviated_base\tquery_len\tid\tone_of_mapped_reference\traw_identity\talign_lent\tmismatch\tgap\tquery_start_position\tquery_end_positon\tsubject_start_position\tsubject_end_position\tE-value\tBlast-score\tMapped_reference\n";

my %raw;
while(<I>)
{
	chomp;
	my @line = split;
	$raw{$line[0]}{$_} = 1;
	$back{$line[0]} = 1;
}
close I;

#----	 re-alignment  --------------
my %new;
for my $id (keys %raw)
{
	for my $l (keys %{$raw{$id}})
	{
		my @line = split /\s+/,$l;
		my $mismat = 0;
		my $ref_len = length($ref_seq{$line[1]});
		my $miss_l = -($line[8]-1);
		my $miss_r = -($ref_len-$line[9]);

		
		# re-align for the 5' 
        	if($line[6] != 1)
		{
                	my $s1 = substr($fa_seq{$line[0]},0,$line[6]-1);
                	my $s2 = substr($ref_seq{$line[1]},0,$line[8]-1);
                	if(length($s2)<length($s1)){
				$miss_l = length($s1)-length($s2);
				$line[3] = $line[3] + length($s2);
                        	$s1 = substr($s1,-length($s2));
                	}else{
				$miss_l = -(length($s2)-length($s1));
				$line[3] = $line[3] + length($s1);
				$s2 = substr($s2,-length($s1));
			}
                	my @s_1 = split //,$s1;
                	my @s_2 = split //,$s2;
			if(scalar@s_1>0 && scalar@s_2>0){
                	for(my $i=0;$i<=$#s_1 ; $i++){
                  		$mismat++ if($s_1[$i] ne $s_2[$i]);
                	}
			}
        	}
		# re-align for the 3'
		if($line[7]!=$fa_len{$line[0]})
		{
			my $s1 = substr($fa_seq{$line[0]},$line[7]);
			my $s2 = substr($ref_seq{$line[1]},$line[9]);
			if(length($s2)<length($s1)){
				$miss_r = length($s1) - length($s2); 
				$line[3] = $line[3] + length($s2);
				$s1 = substr($s1,0,length($s2));
			}else{
				$miss_r = -(length($s2) - length($s1));
				$line[3] = $line[3] + length($s1);
				$s2 = substr($s2,0,length($s1));
			}
			my @s_1 = split //,$s1;
			my @s_2 = split //,$s2;
			if(scalar@s_1>0 && scalar@s_2>0){
			for(my $i=0;$i<=$#s_1 ; $i++){
				$mismat++ if($s_1[$i] ne $s_2[$i]);
			}
			}
		}

        	$line[4] = $line[4] + $mismat;
#        	my $ref_len = (split /_/,$line[1])[2];
        	my $len = $fa_len{$line[0]};


	        my $match = $line[3]-$line[4]-$line[5];
#		my $score = $match - $line[4]*3;
#		$match -= $miss_l if($miss_l>0);
#		$match -= $miss_r if($miss_r>0);
	        my $identify = $match/$len*100;
		my $identify_new = $match/$line[3]*100;
	        $identify = sprintf("%0.2f",$identify);
		$identify_new = sprintf("%0.2f",$identify_new);
		my $miss_len;
        	if($line[1]=~/V/){
                	$miss_len = $miss_r;
        	}else{
			$miss_len = $miss_l;
        	}

        	my $line_new = join "\t" , @line;
		$line_new = "$identify_new\t$miss_len\t$len\t$line_new" ;
		$miss_len = abs($miss_len);
		push @{$new{$line[0]}{$identify}{$miss_len}}, $line_new;
#		print "$line_new\n";
	
	}
}

%raw = ();

#----	output 		----------------
for my $id (keys %new)
{
	my $id_max = (sort {$b <=> $a} keys %{$new{$id}})[0];
	my $id_max_new = (sort {$a <=> $b} keys %{$new{$id}{$id_max}})[0];
	my $ref_all;
	for(@{$new{$id}{$id_max}{$id_max_new}}){
		my @line = split;
		if(defined($ref_all)){
			$ref_all = "$ref_all#$line[4]";
		}else{
			$ref_all = $line[4];
		}
	}
	my $fir = $new{$id}{$id_max}{$id_max_new}->[0];
	$fir = "$fir\t$ref_all";
	print O "$fir\n";

}

for(keys %fa_len)
{
	unless(exists $back{$_})
	{
		print O "-\t-\t$fa_len{$_}\t$_\t-\n";
#		print "-\t-\t$fa_len{$_}\t$_\t-\n";
	}
}

