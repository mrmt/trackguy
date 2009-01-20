# -*-Perl-*-
# TrackGuy / TG.pm
# $Id: trackguy.pl,v 1.23 2000/08/23 11:32:37 morimoto Exp $

require 5.005;
package TG;

use Jcode;
use strict;
use vars qw($title $data_dir $last_br_no_file $last_br_no_lockfile
	    $css_uri $motd $top_uri $namazu_uri $title_prefix
	    %categories_table $hidden_local_domain $commander_rows
	    $color1 $color2 $color3 $color4 $errors_to %label_enum
	    $default_subject $default_from $mta $issue $top_menu
	    $page_footer);

# �����ͤΥǥե����
$data_dir = '/var/spool/trackguy';
$last_br_no_file = '/var/lib/trackguy/lastbr';
$last_br_no_lockfile = '/var/lock/trackguy.lock';
$css_uri = 'trackguy.css';
$motd = '';
$top_uri = 'http://trackguy.mrmt.net';
$namazu_uri = '';
$title = 'TrackGuy �ȥåץڡ���';
$title_prefix = 'TrackGuy';
%categories_table = ();
$hidden_local_domain = '';

$commander_rows = 6;
$color1 = '#eeeeee'; # �����طʤ�������
$color2 = '#333399';
$color3 = '#ccccff'; # ���Ф����� (�����ۤ�)
$color4 = '#9999ff';

$errors_to = '';
$default_subject = 'BTS';
$default_from = 'trackguy@yourdomain.org';
$mta = '';

$issue = q{
    ���ߡ�����ץ�����Τޤ�ư��Ƥ��ޤ���
    lib/trackguy.conf ���Խ����Ƥ���������
    };

$top_menu = qq{
<style type="text/css">
<!--
table.navigator tr td{
	text-align: center;
	background: $TG::color2;
}
-->
</style>
<table class="navigator" width="100%"><tr>
<td><a href="index.cgi"><font color="white"><b>�ȥåץڡ���</b></font></a>
<td><a href="index.cgi?NEW=1"><font color="white"><b>�����ɲ�</b></font></a>
<td><form action="index.cgi">
<font color="white"><b>�ֹ����</b></font>
<input name="NO" type="text" size="4">
</form></td>
</tr></table>};

$page_footer = q{
<address><a href="http://trackguy.mrmt.net/">TrackGuy</a>
- a Bug Tracking System</address>
};

# ����ե������ɾ������ ����Υǥե�����ͤ򥪡��Х饤�ɤ���

require 'trackguy.conf';

################################################################
# ͥ���٤ʤɤΥ�٥��ŤߤĤ������Ȥ���ݤ���
my %label_enum =
    (
     'critical'=>4,
     'high'=>3,
     'normal'=>2,
     'low'=>1,
     'suggested'=>4,
     'scheduled'=>3,
     'reserved'=>2,
     'done'=>1,
     'rejected'=>0,
     );

################################################################
# �Ǹ�� BR �ֹ�����
################################################################
sub last_br_number{
    open(N, $last_br_no_file) ||
	&return_error(500, 'Server Error',
		      "$last_br_no_file �򳫤��ޤ���");
    my $n = scalar <N>;
    close N;
    $n;
}

################################################################
# BR �ο��������ƥ������ֹ���֤�
################################################################
sub new_br_article_no{
    my $n = shift;
    return 0 unless $n;

    my $br_dir = sprintf('%s/%05d', $data_dir, $n);
    return 0 unless -d $br_dir;

    opendir(D, $br_dir);
    my @files = sort(grep(/^\d\d\d\d\d$/, readdir(D)));
    closedir(D);

    $files[-1] + 1;
}

################################################################
# ���� BR �ֹ���֤�
################################################################
sub new_br_number{
    my $n = &last_br_number + 1;
    my $nwait;

    while(-r $last_br_no_lockfile){
	sleep 1;
	if($nwait++ > 10){
	    &return_error(500, 'Server Error',
			  "$last_br_no_file �Υ�å�������ޤ���");
	}
    }

    open(L, "> $last_br_no_lockfile");
    print L $$;
    close L;

    {
	open(N, "> $last_br_no_file") ||
	    &return_error(500, 'Server Error',
			  "$last_br_no_file �˽񤭹���ޤ���");
	print N $n;
	close N;
    }
    unlink $last_br_no_lockfile;
    $n;
}

################################################################
# �ڡ����Υإå������
################################################################
sub print_page_header{
    my $title = shift;
    print q{
	<html>
	<head>
	<meta http-equiv="Content-Type" content="text/html; charset=euc-jp">
	};

    if(length $css_uri){
	print qq{
	    <meta http-equiv="Content-Style-Type" content="text/css">
	    <link rel="StyleSheet" type="text/css" href="$css_uri">
	    };
    }

    if(length $title_prefix){
	print qq{<title>$title_prefix: $title</title>};
    }else{
	print qq{<title>$title</title>};
    }

    print qq{
<style type="text/css">
<!--
h1{
  color: white;
  background: $color2;
}
h2{
  color: $color2;
  border-color: $color2;
  border-width: 0px 0px 2px 0px;
  border-style: solid;
}
h3{
  color: $color2;
  border-color: $color2;
}
h3.error{
  color: red;
}
-->
</style>
</head>
<body>
};

    print $top_menu;
    print "<h1>$title</h1>";
}

################################################################
# �ڡ����Υեå������
# trackguy.conf �ǥ桼������������եå������.
# ������Ƥʤ���С�Ŭ���˥ǥե���Ȥ�Ф�
################################################################
sub page_footer{
    if(length $page_footer){
	print $page_footer;
    }else{
	print q{
	<P><ADDRESS>TrackGuy - a Bug Tracking System</ADDRESS></P>
	</BODY>
	</HTML>
	};
    }
}

################################################################
# ���� BR �ˤĤ��ơ�article �������ɤߡ��ϥå����Ǽ�ᡢ
# �ϥå���λ��Ȥ�������֤�
################################################################
sub read_br($){
    local($_);
    my $br_no = shift;
    my $br_dir = sprintf('%s/%05d', $data_dir, $br_no);

    opendir(D, $br_dir);
    my @files = sort(grep(/^\d\d\d\d\d$/, readdir(D)));
    closedir(D);

    my @br_array;
    for my $f (@files){

	my(%br, @buf, $param, $value);

	unless(open(F, "$br_dir/$f")){
	    return 0;
	}
	@buf = <F>;
	close(F);

	for(@buf){

	    $_ = Jcode->new($_)->h2z->euc;

	    if($param eq 'desc'){
		# ���Ǥ� mail body �����äƤ���
		$br{$param} .= $_;
	    }elsif(/^$/){
		# �ʹ� mail body
		$param = 'desc';
	    }elsif(s/^\s+//){
		# �᡼��إå��η�³��
		chomp;
		$br{$param} .= $_;
	    }elsif(/^([\w-]+):\s*(.*)$/){
                # �᡼��إå�
		$param = lc($1);
		$br{$param} = $2;

		if($param eq 'subject'){
		    $br{$param} = Jcode->new($br{$param})->mime_decode;
		}

	    }else{
		warn "Illegal article line: $br_dir/$f:$.\n";
	    }
	}

	# ����޶��ڤ���ͤ�Ф餷�Ƥ���
	$br{'x-tg-category'} = &normalize_value_list($br{'x-tg-category'});

	# �᡼�륢�ɥ쥹�� �Ф餷�Ƥ���
	$br{'to'} = &normalize_mail_address_list($br{'to'});
	$br{'from'} = &normalize_mail_address_list($br{'from'});

	$br{'date'} = &normalize_date($br{'date'});
	if(length $br{'x-tg-milestone'}){
	    $br{'x-tg-milestone'} = &normalize_date($br{'x-tg-milestone'});
	}

	$br{'no'} = $br_no;

        # warn "--------------------------------------------------------\n";
	# for(keys %br){ warn "$_: $br{$_}\n"; }

	push @br_array, \%br;
    }

    @br_array;
}

################################################################
# HTML ������Ȥ��ä�ʿʸ�ˤ���
# TODO: ������Ŭ��
################################################################
sub plain{
    local($_) = shift;
    s/<[^>]+>//g;
    $_;
}

################################################################
# ����޶��ڤ���ͤ�Ф餷�Ƥ���
################################################################
sub normalize_value_list{
    my $s = shift;
    join(' ', split(/[,\s]+/, $s));
}

################################################################
# ����޶��ڤ���ͤ�Ф餷��ɬ�פʤ�᡼��ɥᥤ����ʬ�򱣤�
################################################################
sub normalize_mail_address_list{
    my $s = shift;
    join(' ', grep(s/${hidden_local_domain}$//,
	 split(/[,\s]+/, $s)));
}

################################################################
# RFC821 �����դ��ñ�ˤ��Ƥ���
# TODO: timezone ̵��
################################################################
sub normalize_date{
    my $s = shift;
    my %month2digit = ('Jan'=>1, 'Feb'=>2, 'Mar'=>3, 'Apr'=>4,
		       'May'=>5, 'Jun'=>6, 'Jul'=>7, 'Aug'=>8,
		       'Sep'=>9, 'Oct'=>10, 'Nov'=>11, 'Dec'=>12);
    my($day, $month, $year, $time) =
	($s =~ /^\w+,\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d\d:\d\d:\d\d)/);
    sprintf('%04d/%02d/%02d %s', $year, $month2digit{$month}, $day, $time);
}

################################################################
# ������ɤ���������Ŭ���˿��Ť�����
# TODO: ������ ad-hoc
################################################################
sub pretty{
    my $s = shift;

    if($s eq 'critical'){
	'<FONT COLOR="#FF0000">�۵�</FONT>';
    }elsif($s eq 'high'){
	'<FONT COLOR="#dd8800">����</FONT>';
    }elsif($s eq 'normal'){
	'<FONT COLOR="#33cc33">����</FONT>';
    }elsif($s eq 'low'){
	'<FONT COLOR="#6666ff">��</FONT>';
    }elsif($s eq 'suggested'){
	'<FONT COLOR="#FF0000">���</FONT>';
    }elsif($s eq 'scheduled'){
	'<FONT COLOR="#999900">���</FONT>';
    }elsif($s eq 'reserved'){
	'<FONT COLOR="#aa9900">��α</FONT>';
    }elsif($s eq 'rejected'){
	'<FONT COLOR="#3333ff">�Ѳ�</FONT>';
    }elsif($s eq 'done'){
	'<FONT COLOR="#009900">��λ</FONT>';
    }
}

################################################################
# ¸�ߤ����� BR �Υꥹ�Ȥ��֤�
################################################################
sub br_list{
    opendir(D, $data_dir);
    my @files = sort(grep(/^\d\d\d\d\d$/, readdir(D)));
    closedir(D);
    @files;
}

################################################################
################################################################
sub http_header{
    my $cookie = shift;

    if($cookie){
	my $str = 'Set-Cookie: ';
	for my $key (keys %$cookie){
	    $str .= "$key=$cookie->{$key}; ";
	}
	$str .= 'hoge=fuga; ';
	$str .= 'expires=Mon, 01-Jan-10 00:00:00 GMT; ';
	$str .= 'path=/';
	print $str, "\r\n";
    }

    print "Content-Type: text/html; charset=euc-jp\r\n\r\n";
}

################################################################
################################################################
sub get_cookie(){
    local($_);

    my %c;
    my $c = $ENV{'HTTP_COOKIE'};
    $c =~ s/;\s*/\t/g;
    my @c = split(/\t/, $c);

    for(@c){
	my ($k, $v) = split(/=/, $_);
	$c{$k} = $v;
    }

    %c;
}

#####################################################################
# &parse_form_data
# action �� GET �Ǥ� POST �Ǥ�������������ꡢϢ�������������֤�
#####################################################################
sub parse_form_data(){
    my($query_string, %form);

    my $request_method = $ENV{'REQUEST_METHOD'};
    if($request_method eq 'GET') {
	$query_string = $ENV{'QUERY_STRING'};
	$query_string =~ s/\?$//;
    }elsif($request_method eq 'POST'){
	read(STDIN, $query_string, $ENV{'CONTENT_LENGTH'});
    }elsif($request_method eq 'HEAD'){
	&return_error(200, 'OK', '');
    }else{
	&return_error(500, 'Server Error',
		      "Server uses unsupported method $request_method");
    }

    for my $key_value (split(/&/, $query_string)){
	my ($key, $value) = split(/=/, $key_value);

	$key =~ tr/+/ /;
	$key =~ s/%([\dA-Fa-f][\dA-Fa-f])/pack('C', hex($1))/eg;

	$value =~ tr/+/ /;
	$value =~ s|%0d%0a|\n|ig;
	$value =~ s/%([\dA-Fa-f][\dA-Fa-f])/pack('C', hex($1))/eg;

	$value = Jcode->new($value)->euc;

	if(defined($form{$key})){
	    $form{$key} .= $; . $value;
	}else{
	    $form{$key} = $value;
	}
    }

    # namazu ����ƤФ줿���� URI �Υ��ߤ���
    # TODO: �ʤ�� ad hoc �ʽ����򤳤�ʤȤ�����������!
    if($form{'NO'}){
	$form{'NO'} =~ s|/.*||;
	$form{'NO'} += 0;
    }

    %form;
}

#####################################################################
# &return_error(�ֹ桢�����Х��顼ʸ����ǽ��);
#
# ���顼���֤��ơ�exit 0 ���롣
# &return_error(500, 'Server Error', '�ɤ�������������');
# ���褤������
# ���Ǥ� Content_type: ���������Ƥ��ޤä���Ǥϡ����ۤɰ�̣���ʤ���
#####################################################################
sub return_error($$$){
    my($status, $keyword, $message) = @_;

    print "Content-type: text/html; charset=euc-jp\n";
    print "Status: $status $keyword\n\n";
    print "<TITLE>CGI Program - Unexpected Error</TITLE>\n";
    print "<H1>$keyword</H1>\n";
    print "<HR>$message</HR>\n";
    exit 0;
}

################################################################
# &, <, > �� HTML ����ƥ��ƥ��˥��������פ���
# ��󥯲�ǽ��ʸ����ϥ�󥯤ˤ����֤�
################################################################
sub escape_and_link($){
    local($_) = shift;
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    unless(s,(http|ftp)(://[!-\177]+),<A TARGET=_new HREF="$1$2">$1$2</A>,g){
        s|(www\.[!-\177]+)|<A TARGET=_new HREF="http://$1">$1</A>|g;
    }
    $_;
}

################################################################
# BR ��ե�����Ȥ��ƽ񤭹���
################################################################
sub write_new_br{
    my $article_no = shift;
    my $br = shift;
    local($_, *O);

    {
	my $outdir = sprintf('%s/%05d', $data_dir, $br->{'NO'});
	unless(-d $outdir){
	    unless(mkdir($outdir, 0755)){
		return undef;
	    }
	}
    }

    my $outfile =
	sprintf('%s/%05d/%05d', $data_dir, $br->{'NO'}, $article_no);
    my @buf;

    {
	my $from = $br->{'from'};
	if(length $hidden_local_domain){
	    $from .= $hidden_local_domain;
	}
	push @buf, "From: $from\n";
	push @buf, "CC: $from\n";
    }

    {
	my @cc;
	for(split(/[, ]+/, $br->{'to'})){
	    if(length $hidden_local_domain){
		$_ = $_ . $hidden_local_domain;
	    }
	    push @cc, $_;
	}
	push @buf, 'To: ' . join(', ', @cc) . "\n";
    }

    push @buf, 'Subject: ' . Jcode->new($br->{'subject'})->mime_encode . "\n";
    push @buf, 'Date: ' . &rfc821date(time) . "\n";
    push @buf, "X-TG-Number: $br->{'NO'}\n";
    push @buf, "X-TG-Article: $article_no\n";
    push @buf, "X-TG-Category: $br->{'x-tg-category'}\n";
    push @buf, "X-TG-Status: $br->{'x-tg-status'}\n";
    push @buf, "X-TG-Priority: $br->{'x-tg-priority'}\n";
    push @buf, "X-TG-Milestone: $br->{'x-tg-milestone'}\n"
	if length $br->{'x-tg-milestone'};
    push @buf, "Content-Type: text/plain; charset=iso-2022-jp\n";
    push @buf, "\n";
    push @buf, Jcode->new($br->{'desc'})->jis;

    unless(open(O, "> $outfile")){
	warn $outfile;
	return undef;
    }
    for(@buf){
	print O;
    }
    close O;
    @buf;
}

################################################################
# BR ��᡼��Ȥ��ƽФ�
################################################################
sub mail_new_br{
    my $article_no = shift;
    my $br = shift;
    local($_, *O);

    my $m =
      TG::Mail->new('Subject' => $br->{'subject'},
		    'X-TG-Number' => $br->{'NO'},
		    'X-TG-Article' => $article_no,
		    'X-TG-Category' => $br->{'x-tg-category'},
		    'X-TG-Status' => $br->{'x-tg-status'},
		    'X-TG-Priority' => $br->{'x-tg-priority'});

    {
	my @cc;
	for(split(/[, ]+/, join(' ', ($br->{'firstfrom'}, $br->{'to'}, $br->{'from'})))){
	    if(length $hidden_local_domain){
		$_ = $_ . $hidden_local_domain;
	    }
	    if(length $_){
		push @cc, $_;
	    }
	}
	$m->header('To' => join(', ', @cc));
    }

    if(length $hidden_local_domain){
	$m->header('From' => $br->{'from'} . $hidden_local_domain);
    }else{
	$m->header('From' => $br->{'from'});
    }

    if(length $br->{'x-tg-milestone'}){
	$m->header('X-TG-Milestone', $br->{'x-tg-milestone'});
    }

    $m->print($br->{'desc'});
    $m->send;
}

################################################################
sub rfc821date{
    my @digit2month =
	qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @digit2wday = qw(Dummy Mon Tue Wed Thu Fri Sat Sun);
    my($sec, $min, $hour, $day, $month, $year, $wday) = localtime(shift);
    sprintf('%s, %d %s %d %02d:%02d:%02d +0900',
	    $digit2wday[$wday], $day, $digit2month[$month],
	    1900 + $year, $hour, $min, $sec);
}

################################################################
# ��ץ饤�Ѥ� > �ǥ���ǥ�Ȥ���
################################################################
sub indent_reply{
    my $s = shift;
    my @buf;
    local($_);

    for(split("\n", $s)){
	push @buf, "> $_\n";
    }
    join('', @buf);
}

################################################################
# ��å������򿷵��񤭹��ߡ���ץ饤����ե������ɽ��
################################################################
sub print_message_form{
    my $msg = shift;
    my $form = shift;
    local($_);

    unless(grep(/^cat_/, (keys %$form))){
	for(split(/\s/, $msg->{'x-tg-category'})){
	    $form->{$_} = 'on';
	}
    }

    unless(defined $form->{'subject'}){
	$form->{'subject'} = $msg->{'subject'};
    }

    unless(defined $form->{'to'}){
	$form->{'to'} = $msg->{'to'};
    }

    unless(defined $form->{'desc'}){
	$form->{'desc'} = TG::indent_reply($msg->{'desc'});
    }

    unless(defined $form->{'x-tg-status'}){
	$form->{'x-tg-status'} = $msg->{'x-tg-status'};
    }

    unless(defined $form->{'x-tg-priority'}){
	$form->{'x-tg-priority'} = $msg->{'x-tg-priority'};
    }

    unless(defined $form->{'x-tg-milestone'}){
	$form->{'x-tg-milestone'} = $msg->{'x-tg-milestone'};
    }

    unless(defined $form->{'x-tg-category'}){
	$form->{'x-tg-category'} = $msg->{'x-tg-category'};
    }

    unless(defined $form->{'x-tg-url'}){
	$form->{'x-tg-url'} = $msg->{'x-tg-url'};
    }

    unless(defined $form->{'firstfrom'}){
	$form->{'firstfrom'} = $msg->{'firstfrom'};
    }

    unless(defined $form->{'x-tg-number'}){
	$form->{'x-tg-number'} = $msg->{'no'};
    }

    print q{
	<script language="JavaScript">
	<!--
	function submitcheck(){
	    with(document.reply){
		if(!from.value.length){
		    alert("�᡼�륢�ɥ쥹�����Ϥ���Ƥ��ޤ���");
		    from.focus(); return;
		}
	    }
	    reply.submit();
	}
	// -->
	</script>};

    print qq{
	<form action="$ENV{'SCRIPT_NAME'}" name="reply" method="post">
	    <table align="center">};

    ################################################################
    # ��̾
    if(defined $form->{'NEW'}){
	print qq{
	<tr><td bgcolor="$color3"><h4>��̾</h4></td>
	<td bgcolor="$color1">
	<input type="text" name="subject" size=40 value="$form->{'subject'}">
	<small><br>
	  ����������̾�򡢴ʷ顢���Τ˽񤤤Ƥ���������<br>
	  ����η�ס�ư���ޤ���פʤɤǤϡ�ï�ⲿ��狼��ޤ���
	</small>
	</td></tr>};
    }else{
	print qq{<input type="hidden" name="subject" value="$form->{'subject'}">};
    }

    ################################################################
    # �����ԤΥ᡼�륢�ɥ쥹
    print qq{
	<tr><td bgcolor="$color3"><h4>���ʤ��Υ᡼�륢�ɥ쥹</h4></td>
	<td bgcolor="$color1">
	<input type="text" size="40" name="from" value="$form->{'from'}">
	<small><br>����ɬ�ܤǤ�.<br>};
    print "$hidden_local_domain ����ʬ�Ͼ�ά���Ƥ��ޤ��ޤ���"
	if length $hidden_local_domain;
    print '</small></td></tr>';

    ################################################################
    # ���ξ���
    if(defined $form->{'NEW'}){

	# �������ξ��ϡ����֤ϡ���ơפ˸���
	print q{
	    <input type="hidden" name="x-tg-status" value="suggested">
	    };

    }else{

	# ���֤����򤵤���
	print qq{
	    <tr><td bgcolor="$color3"><h4>����</h4></td>
		<td bgcolor="$color1">
	    <select name="x-tg-status">};

	my $s = $form->{'x-tg-status'} eq '' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="">(�ѹ����ʤ�)};
	$s = $form->{'x-tg-status'} eq 'suggested' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="suggested">���};
	$s = $form->{'x-tg-status'} eq 'scheduled' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="scheduled">���};
	$s = $form->{'x-tg-status'} eq 'reserved' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="reserved">��α};
	$s = $form->{'x-tg-status'} eq 'done' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="done">��λ};
	$s = $form->{'x-tg-status'} eq 'rejected' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="rejected">�Ѳ�};

	print q{</select><br>
	    <small>
	    ����ơװʳ��ξ��֤������ơפ��᤹�ΤϤ������ᤷ�ޤ���
	     ����ʤ顢�̸ĤΥХ���ݡ��ȤȤ��ƿ����˽񤤤��ۤ��������Ǥ��礦��
	    </small>
	   </td></tr>};

    }

    ################################################################
    # ͥ����
    print qq{
	<tr><td bgcolor="$color3"><h4>ͥ����</h4></td>
	    <td bgcolor="$color1"><select name="x-tg-priority">};

    {
	my $s = $form->{'x-tg-priority'} eq '' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="">(���򤷤Ƥ�������)};
	$s = $form->{'x-tg-priority'} eq 'critical' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="critical">�۵�};
	$s = $form->{'x-tg-priority'} eq 'high' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="high">����};
	$s = $form->{'x-tg-priority'} eq 'normal' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="normal">����};
	$s = $form->{'x-tg-priority'} eq 'low' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="low">��};
    }

    print q{</select></td></tr>};

    ################################################################
    # url
    print qq{
	<tr><td bgcolor="$color3"><h4>url</h4></td>
	<td bgcolor="$color1">
	<input type="text" name="x-tg-url" size=40 value="$form->{'x-tg-url'}">
	<small><br>
	  ɬ�פǤ���С�������ơ����˴ؤ��� url ��񤤤Ƥ�������.
	</small>
	</td></tr>};

    ################################################################
    # ʬ��
    print qq{
	<tr><td bgcolor="$color3"><h4>ʬ����</h4>
	<td bgcolor="$color1">};

    for my $c (sort keys(%TG::categories_table)){
	print qq(<input type="checkbox" name="$c");

	if($form->{$c}){
	    print ' checked';
	}

	print qq{>$categories_table{$c}<BR>\n};
    }

    print '<small>ʣ������Ǥ��ޤ���</small></td></tr>';

    ################################################################
    # �оݼ�
    print qq{
	<tr><td bgcolor="$color3"><h4>�оݼ�</h4></td>
	<td bgcolor="$color1">
	<textarea cols=60 rows=2 name="to">$form->{'to'}</textarea><br>
	<small>
	����ޤ䥹�ڡ��������ԤǶ��ڤäƥ᡼�륢�ɥ쥹���󵭤��Ƥ���������};

    if(length $hidden_local_domain){
	print $hidden_local_domain, ' �Ͼ�ά�Ǥ��ޤ���';
    }
    print '</small></td></tr>';

    if(0){
    ################################################################
    # �ޥ��륹�ȡ���
    print qq{
	<tr><td bgcolor="$color3"><h4>�ޥ��륹�ȡ���</h4></td>
	<td bgcolor="$color1">
	<input type="text" size=40 name="x-tg-milestone" value="$form->{'x-tg-milestone'}">
      <small><br>
       ɬ�פʤ顢yyyy/mm/dd hh:mm:ss �ν񼰤ǻ��ꤷ�Ƥ���������
      </small></td></tr>};
};

    print qq{
	<tr><td bgcolor="$color3"><h4>��å�����</h4>
	<td bgcolor="$color1">
	<textarea cols=40 rows=10 name="desc">$form->{'desc'}</textarea>
	<input type=button onclick="document.reply.desc.value = '';"
	    value="���ꥢ"><br>
	<small>
	�ʷ顦���Ƥ˽񤤤Ƥ���������;ʬ�ʰ��ѡ��������Ĥ����פǤ���
	</small></td></tr>};

    if(defined $form->{'NEW'}){
	print qq{<input type="hidden" name="NEW" value="$form->{'NEW'}">};
    }

    print qq{
	<tr><td align="center" colspan="2" bgcolor="$color2">
	<input type="submit" value="Ok">
	<input type="hidden" name="submit" value="1">
	<input type="hidden" name="firstfrom" value="$form->{'firstfrom'}">
	<input type="hidden" name="NO" value="$form->{'NO'}">
	</td></tr>
	</table>
	</form>};
}

################################################################
# ��ץ饤���Ƥ��������ɤ��������å�����
################################################################
sub check_submitted_form{
    my $form = shift;
    my @err;

    unless(length $form->{'subject'}){
	push @err, '��̾���դ��Ƥ��ޤ���!';
    }

    unless(length $form->{'from'}){
	push @err, 'ȯ���ԤΥ᡼�륢�ɥ쥹���Ϥ�ɬ�ܤǤ�!';
    }

    # url ��Υ������ޤ��䴰
    if(length $form->{'url'}){
	unless($form->{'url'} =~ m/^http/){
	    $form->{'url'} = 'http://' . $form->{'url'};
	}
    }

    unless($form->{'x-tg-priority'}){
	push @err, 'ͥ���٤�����Ǥ�������.';
    }

    unless(grep(/^cat_/, keys %$form)){
	push @err, 'ʬ�������Ǥ�������.';
    }

    my @d = split(/\n/, $form->{'desc'});
    unless(scalar(@d)){
	push @err, '��å������򲿤��񤤤Ƥ�������.';
    }elsif(scalar(grep(/^>/, @d)) == scalar(@d)){
	push @err, '��å������˰���ʸ�������äƤ��ޤ���.';
    }

    @err;
}

################################################################
# ���ϥ��顼���󵭤���
################################################################
sub list_input_errors{
    local($_);
    my @err = @_;

    print q{<h3 class="error">�������Ƥ˥��顼������ޤ�</h2>};

    print '<ul>';

    for(@err){
	print "<li>$_</li>";
    }

    print '</ul>';
}

################################################################
# ���� BR �����
################################################################
sub display_br{
    my $last = shift;
    my $form = shift;
    my @br = @_;

    TG::print_page_header("BTS$form->{'NO'}: $last->{'subject'}");


    # ñ�� BR ��ɽ�������������
    TG::print_report($last);
    TG::print_log(\@br);
    print q{<h2>��ץ饤����</h2>
	<p>
	    ���η�ˤĤ��ơ���ơ��ո��������ʤɤ���ޤ����顢
	    ���ε������Ȥäƥ�ץ饤���Ƥ���������<br>
	    �����κݤˡ����֡�ͥ���١�ʬ����ʤɤϡ�ɬ�פ˱�����
	    Ƚ�Ǥ����ѹ����Ƥ���������
	</p>};
    TG::print_message_form($last, $form);
}

################################################################
# ����Υϥå���˼����줿������ BR �κǿ�������ɽ������
################################################################
sub print_report{
    my $last = shift;

    print '<h2>�ǿ�����</h2>';
    print qq{<table>};

    print qq{<tr><td bgcolor="$color3">����</td>};
    print qq{<td bgcolor="$color1">};
    print &TG::pretty($last->{'x-tg-status'}), '</td></tr>';

    print qq{<tr><td bgcolor="$color3">ͥ����</td>};
    print qq{<td bgcolor="$color1">};
    print &TG::pretty($last->{'x-tg-priority'}), '</td></tr>';

    print qq{<tr><td bgcolor="$color3">ʬ��</td>};
    print qq{<td bgcolor="$color1">};
    print join(', ', grep(s|$_|$categories_table{$_}|,
			  split(/\s/, $last->{'x-tg-category'})));
    print '</td></tr>';

    print qq{<tr><td bgcolor="$color3">�ǽ�����</td>};
    print qq{<td bgcolor="$color1">$last->{'firstfrom'} };
    print qq{<small>($last->{'firstdate'})</small></td></tr>};

    print qq{<tr><td bgcolor="$color3">�Ǹ�Υ�ץ饤</td>};
    print qq{<td bgcolor="$color1">$last->{'lastfrom'} };
    print qq{<small>($last->{'lastdate'})</small></td></tr>};

    print qq{<tr><td bgcolor="$color3">�оݼ�</td>};
    print qq{<td bgcolor="$color1">};
    if(length $last->{'to'}){
	print $last->{'to'};
    }else{
	print '̤��';
    }
    print '</td></tr>';

    print qq{<tr><td bgcolor="$color3">�ޥ��륹�ȡ���</td>};
    print qq{<td bgcolor="$color1">};
    if($last->{'x-tg-milestone'}){
	print "$last->{'x-tg-milestone'}</td></tr>";
    }else{
	print '�ʤ�</td></tr>';
    }

    print qq{<tr><td bgcolor="$color3">URL</td>};
    if(length $last->{'x-tg-url'}){
	print qq{<td bgcolor="$color1"><a href="$last->{'x-tg-url'}">$last->{'x-tg-url'}</a></td></tr>};
    }else{
	print qq{<td bgcolor="$color1">�ʤ�</td></tr>};
    }

    print '</table>';
}

################################################################
#
################################################################
sub print_log{
    my $br = shift;
    my $to = $br->[0]->{'to'};
    my $milestone = $br->[0]->{'x-tg-milestone'};
    my $priority = $br->[0]->{'x-tg-priority'};
    my $url = $br->[0]->{'x-tg-url'};
    my $status = $br->[0]->{'x-tg-status'};

    print '<h2>��</h2>';

    print '<p>������ ', $#$br+1, ' ��Υ�å�����������ޤ�.</p>';

    for my $i (0 .. $#$br){
	my $b = $br->[$i];

	if($i != 0){
	    if($b->{'x-tg-status'} && $to ne $b->{'x-tg-status'}){
		$status = $b->{'x-tg-status'};
	    }
	    if($b->{'x-tg-priority'} && $priority ne $b->{'x-tg-priority'}){
		$priority = $b->{'x-tg-priority'};
	    }
	}

	print qq{<table width="100%"><tr>};
	print qq{<td bgcolor="$color3">};
	print '<b>', $b->{'from'}, '</b><br><small>';
	print $b->{'date'}, ' | ';
	print &TG::pretty($status), ' | ';
	print &TG::pretty($priority);

	if($b->{'x-tg-url'}){
	    print qq{url: <a target="_new" href="$b->{'x-tg-url'}">
			 $b->{'x-tg-url'}</a><br>};
	}

	print '</small></td></tr>';

	# ���ơ������ѹ��������ɽ��
	if($i != 0){
	    my @buf;

	    if($b->{'to'} && $to ne $b->{'to'}){
		if($to){
		    push @buf, "<small>�оݼԤ� <b>$to</b> ����<br><b>$b->{'to'}</b> ���ѹ�����ޤ���<br></small>";
		}else{
		    push @buf, "<small>�оݼԤ� <b>$b->{'to'}</b> �����ꤵ��ޤ���<br></small>";
		}
		$to = $b->{'to'};
	    }

	    if($b->{'x-tg-milestone'}){
		if($milestone ne $b->{'x-tg-milestone'}){
		    if($milestone){
			push @buf, qq{
			    <small>�ޥ��륹�ȡ��� <b>$milestone</b> ����
				<b>$b->{'x-tg-milestone'}</b>
			    ���ѹ�����ޤ���</small>};
		    }else{
			push @buf, qq{
			    <small>�ޥ��륹�ȡ��� <b>$b->{'x-tg-milestone'}</b>
			    �����ꤵ��ޤ���</small>};
		    }
		    $milestone = $b->{'x-tg-milestone'};
		}
	    }

	    if($b->{'x-tg-url'}){
		if($url ne $b->{'x-tg-url'}){
		    if($url){
			push @buf, "<small>URL �� <b>$url</b> ����
                           <br><b>$b->{'x-tg-url'}</b> ���ѹ�����ޤ���<br></small>";
		    }else{
			push @buf, "<small>URL �� <b>$b->{'x-tg-url'}</b> �����ꤵ��ޤ���<br></small>";
		    }
		    $url = $b->{'x-tg-url'};
		}
	    }

	    if(@buf){
		print qq{<tr><td bgcolor="$color4">};
		for(@buf){
		    print $_;
		}
		print '</td></tr>';
	    }
	}

	# ��å������򲽾Ѥ���ɽ��
	{
	    my $msg = &TG::escape_and_link($$b{'desc'});
	    print qq{<tr><td bgcolor="$color1">};
	    $msg =~ s/\n/<br>/g;
	    print $msg;
	    print '</td></tr>';
	}

	if(0){
	    print '<small>';

	    if($b->{'x-tg-milestone'}){
		print qq{
		    <b>�ޥ��륹�ȡ���</b>: $b->{'x-tg-milestone'}<br>
		    };
	    }


	    print '</small>';
	}

	print '</table>';
	print '<hr size=0 width=0>'
    }
}

sub submit_br{
    my $msg = shift;
    my $form = shift;
    TG::print_page_header('��ץ饤');
    TG::commit_br($msg, $form);
}

sub commit_br{
    my $msg = shift;
    my $form = shift;

    if(my @err = TG::check_submitted_form($form)){
	# ��ľ��
        TG::list_input_errors(@err);
	TG::print_message_form($msg, $form);
	exit;
    }

    # ���������ֹ��ȯ���������ե��������¸�����᡼�뤹�롣
    # TODO: �ʲ��ν��������֤�Ȥ����ʤ��Τǥ�å����٤�
    {
	print '<P>������Ǥ������Ф餯���Ԥ�����������</P>';

	my $article_no;

	if(TG::new_br_article_no($form->{'NO'})){
	    $article_no = TG::new_br_article_no($form->{'NO'});
	}else{
	    $article_no = 1;
	    $form->{'NO'} = TG::new_br_number();
	}

        TG::write_new_br($article_no, $form);
        TG::mail_new_br($article_no, $form);
    }

    print qq{
	    <h2>��������Ͽ����λ���ޤ�����</h2>
	    <p>ô���Ԥ����˥᡼�����������ޤ���.</p>
	    <p><a href="${TG::top_uri}/?NO=$form->{'NO'}">
	    <b>����ֹ� BTS$form->{'NO'}: $form->{'subject'}</b>
	    �ι�����̤򸫤�</a><br>
	    <a href="$top_uri/">TrackGuy �ȥåץڡ�����</a></p>
	    };
}

################################################################
# ������å��������
################################################################
sub compose_br{
    my $form = shift;
    my %msg;
    $msg{'x-tg-status'} = 'suggested';
    
    TG::print_page_header('������å�����');

    if(defined $form->{'submit'}){
	# ���Ǥ˵������줿���֤Ǥ������褿�Τʤ顢
	# ���Ƥ�����å�����
        TG::commit_br(\%msg, $form);
	exit;
    }

    print q{
	<h2>������å�����</h2>
	<p>
	    ���ε������Ȥäơ���ơ��ո���񤤤Ƥ���������
	</p>
    };

    TG::print_message_form(\%msg, $form);
}

################################################################
#
################################################################
sub get_last_message{
    my $no = shift;
    my @br = @_;
    my %last;

    $last{'to'} = $br[0]{'to'};
    $last{'x-tg-category'} = $br[0]{'x-tg-category'};
    $last{'x-tg-milestone'} = $br[0]{'x-tg-milestone'};
    $last{'x-tg-priority'} = $br[0]{'x-tg-priority'};
    $last{'x-tg-url'} = $br[0]{'x-tg-url'};
    $last{'x-tg-status'} = $br[0]{'x-tg-status'};

    for my $i (1 .. scalar(@br)){
	my $b = $br[$i];
	if(length $b->{'to'}){
	    $last{'to'} = $b->{'to'};
	}
	if(length $b->{'x-tg-category'}){
	    $last{'x-tg-category'} = $b->{'x-tg-category'};
	}
	if(length $b->{'x-tg-milestone'}){
	    $last{'x-tg-milestone'} = $b->{'x-tg-milestone'};
	}
	if(length $b->{'x-tg-priority'}){
	    $last{'x-tg-priority'} = $b->{'x-tg-priority'};
	}
	if(length $b->{'x-tg-url'}){
	    $last{'x-tg-url'} = $b->{'x-tg-url'};
	}
	if(length $b->{'x-tg-status'}){
	    $last{'x-tg-status'} = $b->{'x-tg-status'};
	}
    }

    $last{'no'} = $br[0]{'no'};
    $last{'subject'} = $br[0]{'subject'};
    $last{'firstdate'} = $br[0]{'date'};
    $last{'lastdate'} = $br[$#br]{'date'};
    $last{'firstfrom'} = $br[0]{'from'};
    $last{'lastfrom'} = $br[$#br]{'from'};
    $last{'desc'} = $br[$#br]{'desc'};

    for(split(/\s/, $last{'x-tg-category'})){
	$last{$_} = 'on';
    }

    %last;
}

1;
