package Blog::Simple;

use 5.6.1;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '0.01';

require XML::XSLT;
use XML::XSLT;

# Preloaded methods go here.
	sub new {
	#instantiate object, create dir/files under path
	
		#get parameters
		my ($obj, $pth) = @_;
		
		if (not defined($pth)) { $pth = ""; }
		
		$pth =~ s/\\/\//g; #turn backslashes into forward
		
		#add the final slash, if needed
		if ($pth ne "") {
			if ($pth !~ /\/$/) { $pth .= "/"; }
		}
		else { $pth = "./"; } #if no path passed, make it the current dir
		
		#create object data structure
		my %sBlog = (
			path => $pth,
			blog_idx => $pth . "bb.idx",
			blog_base => $pth . "b_base/",
			del_list => ''
		);

		#create the paths
		mkdir($sBlog{path}); #root path
		mkdir($sBlog{blog_base});		

		my $sBRef = \%sBlog;		
		bless $sBRef, $obj;
	}

	sub create_index {
	#generate the 'bb.idx' file 

		my $obj = shift;
		
		#create the blog index file
		open(F, ">$obj->{blog_idx}") or die $obj->{blog_idx};
		print F "#path_to_blog	date_stamp	title	author	summary";
		close F;
	}

	sub add {
	#adds a blog to the 'b_base' directory
	
		my ($obj, $title, $author, $email, $smmry, $content) = @_;

		#handle undefined variables
		if (not defined($title)) { $title = ''; }
		if (not defined($author)) { $author = ''; }
		if (not defined($email)) { $email = ''; }
		if (not defined($smmry)) { $smmry = ''; }
		if (not defined($content)) { $content = ''; }

		my $tmp = localtime(time);
		my $ts = $tmp; #for 'bb.idx' entry		
		
		$content =~ s/\t/     /g; #remove any tabs in the content, summary
		$smmry =~ s/\t/     /g;
	
#The core blog XML template
#==========================
		my $blogTmplt =<<END_BT;
	<simple_blog>
	
		<!-- title of blog -->
		<title>$title</title>
		
		<!-- who wrote it -->
		<author>$author</author>
		
		<!-- email -->
		<email>$email</email>

		<!-- timestamp - generated automatically -->
		<ts>$ts</ts>
		
		<!-- just text here - NO TABS -->
		<summary>$smmry</summary>
		
		<!-- put XHTML blog between these tags      -->
		<!--   <img> tags must refer to same folder -->
		<content>$content</content>
	
	</simple_blog>
END_BT
#==========================

		#prepare the directory to be unique
		$tmp =~ s/[\s:]/_/g;
		my $tmpA = $author;
		$tmpA =~ s/[^a-zA-Z]/_/g;
		my $unqDir = $obj->{blog_base} . $tmp . "_" . $tmpA . "/";

		#create the directory
		mkdir($unqDir);
		
		#put 'blog.xml' in it
		open(BF, ">$unqDir"."blog.xml") or die "$unqDir"."blog.xml";
		print BF $blogTmplt;
		close BF;
		
		#save entry to 'bb.idx'
		open(BB, "$obj->{blog_idx}") or die "$obj->{blog_idx}";
		my $bbIdx;
		while (<BB>) { $bbIdx .= $_; }
		close BB;

		my $curLine = "$unqDir"."blog.xml\t$ts\t$title\t$author\t$smmry\n";

		open(BB, ">$obj->{blog_idx}") or die "Writing $obj->{blog_idx}";
		print BB $curLine; print BB $bbIdx;
		close BB;
	}
	
	sub remove {
	#remove entry from bb.idx
	#the parameter passed is a regular expression. This way, multiple entries
	#can be removed simultaneously. Only removes entries from the 'bb.idx' file
	#and returns the paths that need to be removed as an array.
	
		my ($obj, $rex) = @_;

		if (defined($rex)) {
		my @bbI;
		my @delF; 
		
		#get the index, check for matches, return only those lines
		#that do not match
		open(RB, "$obj->{blog_idx}") or die $obj->{blog_idx};
		for (<RB>) { 
			my $chk = $_;
			if ($chk =~ /$rex/) {
				#do the removal code
				my @lA = split(/\t/, $chk);
				push(@delF, $lA[0]);
			}
			else { push(@bbI, $_); }
		}
		close RB;
		
		#write the new index
		open(RB, ">$obj->{blog_idx}") or die $obj->{blog_idx};
		print RB @bbI;
		close RB;
		
		$obj->{del_list} = \@delF;
		} #defined($rex)
		
	}

	sub render_current {
	#this method takes a predetermined number of blogs from the top of the 'bb.idx' file
	#and generates an output file (not necessarily HTML). It relies on XSLT to actually 
	#generate the page, merely concatenating the chosen number of blogs into a single, 
	#temporary XML with a root of '<simple_blog_wrap></simple_blog_wrap>' then running 
	#this file against the XSL file specified.

		my ($obj, $xslFile, $dispNum, $outFile) = @_;
				
		#make sure we're getting a reasonable number of blogs to print
		if ($dispNum < 1) { $dispNum = 1; }
		
		#read in the blog entries from the 'bb.idx' file
		open(BB, "$obj->{blog_idx}") or die $obj->{blog_idx};
		my @getFiles;
		my $cnt=0;
		while (<BB>) {
			next if (($cnt == $dispNum) || ($_ =~ /^\#/));
			my @tmp = split(/\t/, $_);
			push(@getFiles, $tmp[0]);
			$cnt++;
		}
		close BB;

		#open the 'blog.xml' files individually and concatenate into xmlString
		my $xmlString = "<simple_blog_wrap>\n";
		for (@getFiles) {
			my $fil = $_;
			my $preStr;
			open (GF, "$fil") or die "$fil";
			while (<GF>) { $preStr .= $_; }
			close GF;
			$xmlString .= $preStr;
		}
		$xmlString .= "</simple_blog_wrap>\n";

		#process the generated Blog file
		my $xslt = XML::XSLT->new ($xslFile, warnings => 1);
		$xslt->transform ($xmlString);
		
		my $outP = $xslt->toString; 

		if (not defined($outFile)) { #if output file set to nothing, spit to STDOUT
			print $outP;
		}
		else {
			open (OF, ">$obj->{path}". $outFile);
			print OF $outP;
			close OF;
		}
			
	}
	
	sub get_index {
	#used to return the 'bb.idx' file as an array of lines from the file
		
		my $obj = shift;
		my @ret;
		
		open(GBI, "$obj->{blog_idx}") or die $obj->{blog_idx};
		for (<GBI>) { push(@ret, $_); }
		return @ret;
		
	}
	
	sub render_all {
	#this subroutine creates an archive output by opening 'bb.idx' and
	#concatentating all the <simple_blog></simple_blog> files in the 
	#blogbase into a single string, and processing it with an XSL file
	#of the users determination. Works nearly identical to gen_Blog_Current,
	#except it gets all blogs, not just the 'n' most current.

		my ($obj, $xslFile, $outFile) = @_;
			
		#read in the blog entries from the 'bb.idx' file
		open(BB, "$obj->{blog_idx}") or die $obj->{blog_idx};
		my @getFiles;
		while (<BB>) {
			next if ($_ =~ /^\#/);
			my @tmp = split(/\t/, $_);
			push(@getFiles, $tmp[0]);
		}
		close BB;

		#open the 'blog.xml' files individually and concatenate into xmlString
		my $xmlString = "<simple_blog_wrap>\n";
		for (@getFiles) {
			my $fil = $_;
			my $preStr;
			open (GF, "$fil") or die "$fil";
			while (<GF>) { $preStr .= $_; }
			close GF;
			$xmlString .= $preStr;
		}
		$xmlString .= "</simple_blog_wrap>\n";

		#process the generated Blog file
		my $xslt = XML::XSLT->new ($xslFile, warnings => 1);
		$xslt->transform ($xmlString);
		
		my $outP = $xslt->toString; 

		if (not defined($outFile)) { #if output file not defined, spit to STDOUT
			print $outP;
		}
		else {
			open (OF, ">$obj->{path}". $outFile);
			print OF $outP;
			close OF;
		}
		
	}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Blog::Simple - Perl extension for the creation of a simple weblog (blogger) system.

=head1 SYNOPSIS
	
use Blog::Simple;
  
my $sbO = Blog::Simple->new();
$sbO->create_index(); #generally only needs to be called once
  
my $content="<p>blah blah blah in XHTML</p>
<p><b>Better</b> when done in XHTML</p>";
my $title = 'some title';
my $author = 'a.n. author';
my $email = 'anaouthor@somedomain.net';
my $smmry = 'blah blah';
$sbO->add($title,$author,$email,$smmry,$content);
  
$sbO->render_current('blog_test.xsl',3);
$sbO->render_all('blog_test.xsl');
  
$sbO->remove('08');

=head1 REQUIRES

XML::XSL

=head1 EXPORT

None by default.

=head1 DESCRIPTION

This module provides a simple mechanism for blogging, the reverse chronological diary-like systems so popular on the Internet today. It was intended to be simple, and just handles the basics of blogging: managing blog entries (adding, removing -- there probably should be a 'modify,' but there isn't), generating the most recent I<n> entries, and generating all of the entries in the 'blogbase'. 

Blog::Simple requires that the XML::XSL module be installed. Rather than try and do the rendering itself, it passes the XML that it generates to an XSL file that the user creates. So you will need to know XSLT to really find this module useful.

Blog::Simple generates XML files and stores them in a blogbase and in a timestamped subfolder. The blogbase consists of a folder under the path you specify in your code called F<b_base> and a file called F<bb.idx>. If no path is given, then it uses the directory the calling Perl file is saved in. F<bb.idx> contains a tab-delimited list of the path, datestamp, title, author, summary of each blog entry. The Blog::Simple generated XML files are stored underneath F<b_base> in automatically generated timestamped folders.

The XML entry for a blog is rendered as follows (this XML template is hardcoded in the C<add()> method):

	<simple_blog>
	
		<!-- title of blog -->
		<title>$title</title>
		
		<!-- who wrote it -->
		<author>$author</author>
		
		<!-- email -->
		<email>$email</email>

		<!-- timestamp - generated automatically -->
		<ts>$ts</ts>
		
		<!-- just text here - NO TABS -->
		<summary>$smmry</summary>
		
		<!-- put XHTML blog between these tags      -->
		<!--   <img> tags must refer to same folder -->
		<content>$content</content>
	
	</simple_blog>


When you tell Blog::Simple to generate its output, you will need an XSL document. One I used for testing looks like:

	<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	
		<!-- this is the main template match -->
		<xsl:template match="/">
			<xsl:apply-templates select="simple_blog_wrap/simple_blog"/>              
		</xsl:template>

		<xsl:template match="simple_blog">
			<xsl:apply-templates select="title"/>
			<xsl:apply-templates select="ts"/>
			<xsl:apply-templates select="content"/>	
		</xsl:template>

		<xsl:template match="title"><xsl:copy-of select="."/></xsl:template>

		<xsl:template match="ts"><xsl:copy-of select="."/></xsl:template>

		<xsl:template match="content"><xsl:copy-of select="."/></xsl:template>

	</xsl:stylesheet>

That should get you started. An XSL stylesheet is required when you invoke the C<render_current()> and C<render_all()> methods. Blog::Simple wraps a root element around all the C<E<lt>simple_blogE<gt>E<lt>/simple_blogE<gt>> elements it renders called C<E<lt>simple_blog_wrapE<gt>E<lt>/simple_blog_wrapE<gt>>. Keep this in mind when you are writing your XSL stylesheet.

=head1 METHODS

=head3 C<new( [$path] )>

The new() method instantiates a new Blog::Simple object. It sets the path to the blogbase, defaulting to the directory of the calling script if no path is given. Use relative or absolute paths. For example:

	$sbO = Blog::Simple->new('c:/absolute/path');

or

	$sbO = Blog::Simple->new('../path/to/somewhere/relative');

=head3 C<create_index()>

Call this method only once per blogbase you create. It merely generates the files necessary for Blog::Simple to work. You can manually create them somewhere, if you create the file F<bb.idx> and the subdirectory F<b_base> in some directory F<dir> on your system, and then pass this path to the C<new()> method. The resulting file structure in any case should be

	  <path>/
		/bb.idx 
		/b_base

There are no arguments for this method.

	$sbO->create_index();

=head3 C<add( $title, $author, $email, $smmry, $content )>

This adds an entry into the blogbase. It generates the XML and stores it as a file in a subdirectory below F<b_base>. It also updates the blogbase, F<bb.idx>, generating a timestamp and putting it at the head of the file. 

	$sbO->add('some title', 'some author', 'sa@somewhere.net', 'some summary', 'some content, etc, etc...');

=head3 C<remove( $regex )>

This method takes a regular expression, and searches through the F<bb.idx> file, removing the entries that match. It creates an array of the paths of the entries it has removed, and stuffs a reference of it in a hash key associated with the object, called C<del_list>. It does not remove the directories from the F<b_base> directory; the array it returns can be used to do this.

	$sbO->remove('\:1[5-6]');

In order to access the array of deleted paths, the value of

	$sbO->{del_list};

is a reference to the created array, whose elements can be gotten by using 

	while(@{$sbO->{del_list}}) {
		#process elements
	}

or some such.

=head3 C<render_current( $xsl_file [, $display_num, $out_file] )>

This method processes an arbitrary number of the most recent blog entries against an XSL stylesheet that is passed as an argument. You pass it the stylesheet path/filename, and the number of entries to process. It will retrieve the entries from the filesystem, and wrap them in the root element C<E<lt>simple_blog_wrapE<gt>E<lt>/simple_blog_wrapE<gt>> before passing them to your stylesheet. If the C<$display_num> parameter is missing, the method defaults to 1, and returns one blog entry. C<$outfile> is the path/filename to the output file. If you do not specify this, output is returned to C<STDOUT>. 

	$sbO->render_current('myxslfile.xsl', 3, 'output.html');

generates three blog entries and saves them to the file F<output.html>. The same call, but sent to standard output:

	$sbO->render_current('myxslfile.xsl', 3);

=head3 C<render_all( $xsl_file [, $out_file] )>

C<render_all()> looks up all the blog entries stored in the blogbase and applies the stylesheet you provide against it. C<$out_file> specifies a path/filename to save the output to.

	$sbO->render_all('mystylesheet.xsl');

or 
	
	$sbO->render_all('mystylesheet.xsl', 'output.html');

=head3 C<get_index()>

This method simply reads in the F<bb.idx> file entry by entry (line by line), and returns it as an array. This is a useful method for doing custom things with the blogbase.

	my @bI = $sB->get_index();

=head1 AUTHOR

J. A. Robson, E<lt>gilad@arbingersys.comE<gt>

=head1 SEE ALSO

XML, XSLT, Regular Expressions, XML::XSL

=cut
