package Win32::Scsv;

use strict;
use warnings;

use Win32::OLE;
use Win32::OLE::Variant;
use Carp;
use File::Spec;
use File::Copy;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw();
our @EXPORT_OK = qw(xls_2_csv csv_2_xls empty_xls get_xver);
our $VERSION   = '0.06';

# List of constants Win32::OLE::Const 'Microsoft Excel'
# =====================================================
# xlCSV             =     6
# xlExcel2          =    16
# xlExcel3          =    29
# xlExcel4          =    33
# xlExcel5          =    39
# xlExcel7          =    39
# xlExcel9795       =    43
# xlOpenXMLWorkbook =    51
# xlExcel8          =    56
# xlNormal          = -4143
# xlPasteValues     = -4163

my $fmt_csv   =     6;
my $fmt_xls   = -4143;
my $fmt_xlsx  =    51;
my $fmt_value = -4163;

my $vtfalse = Variant(VT_BOOL, 0);
my $vttrue  = Variant(VT_BOOL, 1);

my $ole_global;

# Comment by Klaus Eichner, 11/02/2012
#
# I have copied the example code from
# http://bytes.com/topic/perl/answers/770333-how-convert-csv-file-excel-file
#
# ...and from
# http://www.tek-tips.com/faqs.cfm?fid=6715
#
# ...also an excellent source of information with regards to Win32::Ole / Excel is the
# perlmonks-article ("Using Win32::OLE and Excel - Tips and Tricks") at the following site:
# http://www.perlmonks.org/bare/?node_id=153486
#
# ...In that perlmonks-article there is a link to another article
# ("The Perl Journal #10, courtesy of Jon Orwant")
# http://search.cpan.org/~gsar/libwin32-0.191/OLE/lib/Win32/OLE/TPJ.pod
#
# ...I found the following site to identify the different Excel versions (12.0 -> 2007, 11.0 -> 2003, etc...):
# http://www.mrexcel.com/forum/excel-questions/357733-visual-basic-applications-test-finding-excel-version.html

sub get_xver {
    my $ole_excel = get_excel() or croak "Can't start Excel";

    my $ver = $ole_excel->Version;
    my $prd =
      $ver eq '12.0' ? '2007' :
      $ver eq '11.0' ? '2003' :
      $ver eq '10.0' ? '2002' :
      $ver eq  '9.0' ? '2000' :
      $ver eq  '8.0' ? '1997' :
      $ver eq  '7.0' ? '1995' : '????';

    return ($ver, $prd) if wantarray;
    return $ver;
}

sub xls_2_csv {
    my ($xls_name, $xls_snumber) = $_[0] =~ m{\A ([^%]*) % ([^%]*) \z}xms ? ($1, $2) : ($_[0], 1);
    my $csv_name = $_[1];

    unless ($xls_name =~ m{\A (.*) \. (xls x?) \z}xmsi) {
        croak "xls_name '$xls_name' does not have an Excel extension (*.xls, *.xlsx)";
    }

    my ($xls_stem, $xls_ext) = ($1, lc($2));

    unless (-f $xls_name) {
        croak "xls_name '$xls_name' not found";
    }

    my $xls_abs = File::Spec->rel2abs($xls_name); $xls_abs =~ s{/}'\\'xmsg;
    my $csv_abs = File::Spec->rel2abs($csv_name); $csv_abs =~ s{/}'\\'xmsg;

    # remove the CSV file (if it exists)
    if (-e $csv_abs) {
        unlink $csv_abs or croak "Can't unlink csv_abs '$csv_abs' because $!";
    }

    my $ole_excel = get_excel() or croak "Can't start Excel";

    my $xls_book = $ole_excel->Workbooks->Open($xls_abs)
       or croak "Can't Workbooks->Open xls_abs '$xls_abs'";

    my $xls_sheet = $xls_book->Worksheets($xls_snumber)
       or croak "Can't find Sheet '$xls_snumber' in xls_abs '$xls_abs'";

    $xls_sheet->Activate;
    $xls_book->SaveAs($csv_abs, $fmt_csv);
    $xls_book->Close;
}

sub csv_2_xls {
    my ($xls_name, $xls_snumber) = $_[1] =~ m{\A ([^%]*) % ([^%]*) \z}xms ? ($1, $2) : ($_[1], 1);
    my $csv_name = $_[0];

    my $tpl_name   = $_[2] && defined($_[2]{'tpl'})  ? $_[2]{'tpl'}    : '';
    my @col_size   = $_[2] && defined($_[2]{'csz'})  ? @{$_[2]{'csz'}} : ();
    my @col_fmt    = $_[2] && defined($_[2]{'fmt'})  ? @{$_[2]{'fmt'}} : ();
    my $sheet_prot = $_[2] && defined($_[2]{'prot'}) ? $_[2]{'prot'}   : 0;

    my $init_new = 0;

    if ($tpl_name eq '*') {
        $init_new = 1;
        $tpl_name = '';
    }

    my ($xls_stem, $xls_ext) = $xls_name =~ m{\A (.*) \. (xls x?) \z}xmsi ? ($1, lc($2)) :
      croak "xls_name '$xls_name' does not have an Excel extension of the right type (*.xls, *.xlsx)";

    my $xls_format = $xls_ext eq 'xls' ? $fmt_xls : $fmt_xlsx;

    my ($tpl_stem, $tpl_ext) =
      $tpl_name eq ''                            ? ('', '')     :
      $tpl_name =~ m{\A (.*) \. (xls x?) \z}xmsi ? ($1, lc($2)) :
      croak "tpl_name '$tpl_name' does not have an Excel extension of the right type (*.xls, *.xlsx)";

    unless ($tpl_name eq '' or $tpl_ext eq $xls_ext) {
        croak "extensions do not match between ".
          "xls and tpl ('$xls_ext', '$tpl_ext'), name is ('$xls_name', '$tpl_name')";
    }

    my $xls_abs = $xls_name eq '' ? '' : File::Spec->rel2abs($xls_name); $xls_abs =~ s{/}'\\'xmsg;
    my $tpl_abs = $tpl_name eq '' ? '' : File::Spec->rel2abs($tpl_name); $tpl_abs =~ s{/}'\\'xmsg;
    my $csv_abs = $csv_name eq '' ? '' : File::Spec->rel2abs($csv_name); $csv_abs =~ s{/}'\\'xmsg;

    if ($init_new) {
        if (-e $xls_abs) {
            unlink $xls_abs or croak "Can't unlink '$xls_abs' because $!";
        }

        my $tmp_ole = get_excel() or croak "Can't start Excel (tmp)";
        my $tmp_book = $tmp_ole->Workbooks->Add or croak "Can't Workbooks->Add xls_abs '$xls_abs' (tmp)";
        $tmp_book->SaveAs($xls_abs, $xls_format);
        $tmp_book->Close;
    }

    if ($tpl_name eq '') {
        unless (-f $xls_name) {
            croak "xls_name ('$xls_name') does not exist and template was not specified";
        }
    }
    else {
        unlink $xls_name;
        copy $tpl_name, $xls_name
          or croak "Can't copy tpl_name to xls_name ('$tpl_name', '$xls_name') because $!";
    }

    unless ($csv_abs eq '' or -f $csv_abs) {
        croak "csv_abs '$csv_abs' not found";
    }

    unless ($tpl_abs eq '' or -f $tpl_abs) {
        croak "tpl_abs '$tpl_abs' not found";
    }

    my $ole_excel = get_excel() or croak "Can't start Excel (new)";
    my $xls_book  = $ole_excel->Workbooks->Open($xls_abs) or croak "Can't Workbooks->Open xls_abs '$xls_abs'";
    my $xls_sheet = $xls_book->Worksheets($xls_snumber) or croak "Can't find Sheet '$xls_snumber' in xls_abs '$xls_abs'";

    $xls_sheet->Activate; # "...->Activate" is necessary in order to allow "...Range('A1')->Select" later to be effective
    $xls_sheet->Unprotect; # unprotect the sheet in any case...
    $xls_sheet->Columns($_->[0])->{NumberFormat} = $_->[1] for @col_fmt;

    unless ($csv_abs eq '') {
        my $csv_book  = $ole_excel->Workbooks->Open($csv_abs) or croak "Can't Workbooks->Open csv_abs '$csv_abs'";
        my $csv_sheet = $csv_book->Worksheets(1) or croak "Can't find Sheet #1 in csv_abs '$csv_abs'";

        $xls_sheet->Cells->ClearContents;
        $csv_sheet->Cells->Copy;
        $xls_sheet->Range('A1')->PasteSpecial($fmt_value);
        $xls_sheet->Cells->EntireColumn->AutoFit;

        $csv_book->Close;
    }

    $xls_sheet->Columns($_->[0])->{ColumnWidth}  = $_->[1] for @col_size;

    $xls_sheet->Range('A1')->Select;

    if ($sheet_prot) {
        $xls_sheet->Protect({
          DrawingObjects => $vttrue, 
          Contents       => $vttrue, 
          Scenarios      => $vttrue,
        });
    }

    $xls_book->SaveAs($xls_abs, $xls_format); # ...always use SaveAs(), never use Save() here ...
    $xls_book->Close;
}

sub empty_xls {
    my $xls_name = $_[0];

    my ($xls_stem, $xls_ext) = $xls_name =~ m{\A (.*) \. (xls x?) \z}xmsi ? ($1, lc($2)) :
      croak "xls_name '$xls_name' does not have an Excel extension (*.xls, *.xlsx)";

    my $xls_format = $xls_ext eq 'xls' ? $fmt_xls : $fmt_xlsx;

    my $xls_abs = File::Spec->rel2abs($xls_name); $xls_abs =~ s{/}'\\'xmsg;

    my $ole_excel = get_excel() or croak "Can't start Excel";
    my $xls_book  = $ole_excel->Workbooks->Add or croak "Can't Workbooks->Add xls_abs '$xls_abs'";
    my $xls_sheet = $xls_book->Worksheets(1) or croak "Can't find Sheet '1' in xls_abs '$xls_abs'";

    $xls_book->SaveAs($xls_abs, $xls_format);
    $xls_book->Close;
}

sub get_excel {
    return $ole_global if $ole_global;

    # use existing instance if Excel is already running
    my $ol1 = eval { Win32::OLE->GetActiveObject('Excel.Application') };
    return if $@;

    unless (defined $ol1) {
        $ol1 = Win32::OLE->new('Excel.Application', sub {$_[0]->Quit;})
          or return;
    }
 
    $ole_global = $ol1;
    $ole_global->{DisplayAlerts} = 0;

    return $ole_global;
}

1;

__END__

=head1 NAME

Win32::Scsv - Convert from and to *.xls, *.csv using Win32::OLE

=head1 SYNOPSIS

    use Win32::Scsv qw(xls_2_csv csv_2_xls empty_xls get_xver);

    xls_2_csv('Test Excel File.xlsx%Tabelle3' => 'dummy.csv');
    xls_2_csv('Test Excel File.xlsx%Tabelle Test');

    csv_2_xls('dummy.csv' => 'New.xls%Tab9', {
      'tpl'  => 'Template.xls',
      'csz'  => [['H:H' => 13.71], ['A:D' => 3]],
      'fmt'  => [['A:A' => '#,##0.000'], ['B:B' => '\\<@\\>'], ['C:C' => 'dd/mm/yyyy hh:mm:ss']],
      'prot' => 1,
    });

    empty_xls('abc.xls');
    empty_xls('def.xlsx');

    my ($ver, $product) = get_xver;

=head1 AUTHOR

Klaus Eichner <klaus03@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011 by Klaus Eichner

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms of the artistic license 2.0,
see http://www.opensource.org/licenses/artistic-license-2.0.php

=cut
