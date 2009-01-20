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

# 設定値のデフォルト
$data_dir = '/var/spool/trackguy';
$last_br_no_file = '/var/lib/trackguy/lastbr';
$last_br_no_lockfile = '/var/lock/trackguy.lock';
$css_uri = 'trackguy.css';
$motd = '';
$top_uri = 'http://trackguy.mrmt.net';
$namazu_uri = '';
$title = 'TrackGuy トップページ';
$title_prefix = 'TrackGuy';
%categories_table = ();
$hidden_local_domain = '';

$commander_rows = 6;
$color1 = '#eeeeee'; # セル背景の薄い色
$color2 = '#333399';
$color3 = '#ccccff'; # 見出しセル (薄いほう)
$color4 = '#9999ff';

$errors_to = '';
$default_subject = 'BTS';
$default_from = 'trackguy@yourdomain.org';
$mta = '';

$issue = q{
    現在、サンプル設定のまま動作しています。
    lib/trackguy.conf を編集してください。
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
<td><a href="index.cgi"><font color="white"><b>トップページ</b></font></a>
<td><a href="index.cgi?NEW=1"><font color="white"><b>新規追加</b></font></a>
<td><form action="index.cgi">
<font color="white"><b>番号指定</b></font>
<input name="NO" type="text" size="4">
</form></td>
</tr></table>};

$page_footer = q{
<address><a href="http://trackguy.mrmt.net/">TrackGuy</a>
- a Bug Tracking System</address>
};

# 設定ファイルを評価して 設定のデフォルト値をオーバライドする

require 'trackguy.conf';

################################################################
# 優先度などのラベルを重みつけソートする際の値
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
# 最後の BR 番号を取得
################################################################
sub last_br_number{
    open(N, $last_br_no_file) ||
	&return_error(500, 'Server Error',
		      "$last_br_no_file を開けません");
    my $n = scalar <N>;
    close N;
    $n;
}

################################################################
# BR の新規アーティクル番号を返す
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
# 新規 BR 番号を返す
################################################################
sub new_br_number{
    my $n = &last_br_number + 1;
    my $nwait;

    while(-r $last_br_no_lockfile){
	sleep 1;
	if($nwait++ > 10){
	    &return_error(500, 'Server Error',
			  "$last_br_no_file のロックが外れません");
	}
    }

    open(L, "> $last_br_no_lockfile");
    print L $$;
    close L;

    {
	open(N, "> $last_br_no_file") ||
	    &return_error(500, 'Server Error',
			  "$last_br_no_file に書き込めません");
	print N $n;
	close N;
    }
    unlink $last_br_no_lockfile;
    $n;
}

################################################################
# ページのヘッダを出力
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
# ページのフッタを出力
# trackguy.conf でユーザが定義したフッタを出力.
# 定義してなければ、適当にデフォルトを出す
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
# ある BR について、article を全部読み、ハッシュに納め、
# ハッシュの参照の配列を返す
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
		# すでに mail body に入っている
		$br{$param} .= $_;
	    }elsif(/^$/){
		# 以降 mail body
		$param = 'desc';
	    }elsif(s/^\s+//){
		# メールヘッダの継続行
		chomp;
		$br{$param} .= $_;
	    }elsif(/^([\w-]+):\s*(.*)$/){
                # メールヘッダ
		$param = lc($1);
		$br{$param} = $2;

		if($param eq 'subject'){
		    $br{$param} = Jcode->new($br{$param})->mime_decode;
		}

	    }else{
		warn "Illegal article line: $br_dir/$f:$.\n";
	    }
	}

	# カンマ区切りの値をばらしておく
	$br{'x-tg-category'} = &normalize_value_list($br{'x-tg-category'});

	# メールアドレスも ばらしておく
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
# HTML エレメントを取って平文にする
# TODO: すごい適当
################################################################
sub plain{
    local($_) = shift;
    s/<[^>]+>//g;
    $_;
}

################################################################
# カンマ区切りの値をばらしておく
################################################################
sub normalize_value_list{
    my $s = shift;
    join(' ', split(/[,\s]+/, $s));
}

################################################################
# カンマ区切りの値をばらし、必要ならメールドメイン部分を隠す
################################################################
sub normalize_mail_address_list{
    my $s = shift;
    join(' ', grep(s/${hidden_local_domain}$//,
	 split(/[,\s]+/, $s)));
}

################################################################
# RFC821 な日付を簡単にしておく
# TODO: timezone 無視
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
# キーワードを和訳して適当に色づけする
# TODO: すごい ad-hoc
################################################################
sub pretty{
    my $s = shift;

    if($s eq 'critical'){
	'<FONT COLOR="#FF0000">緊急</FONT>';
    }elsif($s eq 'high'){
	'<FONT COLOR="#dd8800">重要</FONT>';
    }elsif($s eq 'normal'){
	'<FONT COLOR="#33cc33">普通</FONT>';
    }elsif($s eq 'low'){
	'<FONT COLOR="#6666ff">低</FONT>';
    }elsif($s eq 'suggested'){
	'<FONT COLOR="#FF0000">提案</FONT>';
    }elsif($s eq 'scheduled'){
	'<FONT COLOR="#999900">着手</FONT>';
    }elsif($s eq 'reserved'){
	'<FONT COLOR="#aa9900">保留</FONT>';
    }elsif($s eq 'rejected'){
	'<FONT COLOR="#3333ff">却下</FONT>';
    }elsif($s eq 'done'){
	'<FONT COLOR="#009900">完了</FONT>';
    }
}

################################################################
# 存在する全 BR のリストを返す
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
# action が GET でも POST でも等しく受け取り、連想配列に入れて返す
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

    # namazu から呼ばれた場合の URI のゴミを取る
    # TODO: なんで ad hoc な処理をこんなところに入れるんだ!
    if($form{'NO'}){
	$form{'NO'} =~ s|/.*||;
	$form{'NO'} += 0;
    }

    %form;
}

#####################################################################
# &return_error(番号、サーバエラー文字列、能書き);
#
# エラーを返して、exit 0 する。
# &return_error(500, 'Server Error', 'どうしたこうした');
# がよいだろう。
# すでに Content_type: を送信してしまった後では、さほど意味がない。
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
# &, <, > を HTML エンティティにエスケープし、
# リンク可能な文字列はリンクにして返す
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
# BR をファイルとして書き込む
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
# BR をメールとして出す
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
# リプライ用に > でインデントする
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
# メッセージを新規書き込み・リプライするフォームを表示
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
		    alert("メールアドレスが入力されていません");
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
    # 題名
    if(defined $form->{'NEW'}){
	print qq{
	<tr><td bgcolor="$color3"><h4>題名</h4></td>
	<td bgcolor="$color1">
	<input type="text" name="subject" size=40 value="$form->{'subject'}">
	<small><br>
	  この報告の題名を、簡潔、明確に書いてください。<br>
	  「例の件」「動きません」などでは、誰も何もわかりません。
	</small>
	</td></tr>};
    }else{
	print qq{<input type="hidden" name="subject" value="$form->{'subject'}">};
    }

    ################################################################
    # 記入者のメールアドレス
    print qq{
	<tr><td bgcolor="$color3"><h4>あなたのメールアドレス</h4></td>
	<td bgcolor="$color1">
	<input type="text" size="40" name="from" value="$form->{'from'}">
	<small><br>記入必須です.<br>};
    print "$hidden_local_domain の部分は省略してかまいません"
	if length $hidden_local_domain;
    print '</small></td></tr>';

    ################################################################
    # 報告の状態
    if(defined $form->{'NEW'}){

	# 新規報告の場合は、状態は「提案」に固定
	print q{
	    <input type="hidden" name="x-tg-status" value="suggested">
	    };

    }else{

	# 状態を選択させる
	print qq{
	    <tr><td bgcolor="$color3"><h4>状態</h4></td>
		<td bgcolor="$color1">
	    <select name="x-tg-status">};

	my $s = $form->{'x-tg-status'} eq '' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="">(変更しない)};
	$s = $form->{'x-tg-status'} eq 'suggested' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="suggested">提案};
	$s = $form->{'x-tg-status'} eq 'scheduled' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="scheduled">着手};
	$s = $form->{'x-tg-status'} eq 'reserved' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="reserved">保留};
	$s = $form->{'x-tg-status'} eq 'done' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="done">完了};
	$s = $form->{'x-tg-status'} eq 'rejected' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="rejected">却下};

	print q{</select><br>
	    <small>
	    「提案」以外の状態から「提案」に戻すのはおすすめしません。
	     それなら、別個のバグレポートとして新規に書いたほうがいいでしょう。
	    </small>
	   </td></tr>};

    }

    ################################################################
    # 優先度
    print qq{
	<tr><td bgcolor="$color3"><h4>優先度</h4></td>
	    <td bgcolor="$color1"><select name="x-tg-priority">};

    {
	my $s = $form->{'x-tg-priority'} eq '' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="">(選択してください)};
	$s = $form->{'x-tg-priority'} eq 'critical' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="critical">緊急};
	$s = $form->{'x-tg-priority'} eq 'high' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="high">重要};
	$s = $form->{'x-tg-priority'} eq 'normal' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="normal">普通};
	$s = $form->{'x-tg-priority'} eq 'low' ? 'SELECTED' : '';
	print qq{<OPTION $s VALUE="low">低};
    }

    print q{</select></td></tr>};

    ################################################################
    # url
    print qq{
	<tr><td bgcolor="$color3"><h4>url</h4></td>
	<td bgcolor="$color1">
	<input type="text" name="x-tg-url" size=40 value="$form->{'x-tg-url'}">
	<small><br>
	  必要であれば、この提案・報告に関する url を書いてください.
	</small>
	</td></tr>};

    ################################################################
    # 分類
    print qq{
	<tr><td bgcolor="$color3"><h4>分類先</h4>
	<td bgcolor="$color1">};

    for my $c (sort keys(%TG::categories_table)){
	print qq(<input type="checkbox" name="$c");

	if($form->{$c}){
	    print ' checked';
	}

	print qq{>$categories_table{$c}<BR>\n};
    }

    print '<small>複数指定できます。</small></td></tr>';

    ################################################################
    # 対象者
    print qq{
	<tr><td bgcolor="$color3"><h4>対象者</h4></td>
	<td bgcolor="$color1">
	<textarea cols=60 rows=2 name="to">$form->{'to'}</textarea><br>
	<small>
	カンマやスペース、改行で区切ってメールアドレスを列記してください。};

    if(length $hidden_local_domain){
	print $hidden_local_domain, ' は省略できます。';
    }
    print '</small></td></tr>';

    if(0){
    ################################################################
    # マイルストーン
    print qq{
	<tr><td bgcolor="$color3"><h4>マイルストーン</h4></td>
	<td bgcolor="$color1">
	<input type="text" size=40 name="x-tg-milestone" value="$form->{'x-tg-milestone'}">
      <small><br>
       必要なら、yyyy/mm/dd hh:mm:ss の書式で指定してください。
      </small></td></tr>};
};

    print qq{
	<tr><td bgcolor="$color3"><h4>メッセージ</h4>
	<td bgcolor="$color1">
	<textarea cols=40 rows=10 name="desc">$form->{'desc'}</textarea>
	<input type=button onclick="document.reply.desc.value = '';"
	    value="クリア"><br>
	<small>
	簡潔・明瞭に書いてください。余分な引用・あいさつは不要です。
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
# リプライ内容が正当かどうかチェックする
################################################################
sub check_submitted_form{
    my $form = shift;
    my @err;

    unless(length $form->{'subject'}){
	push @err, '題名が付いていません!';
    }

    unless(length $form->{'from'}){
	push @err, '発言者のメールアドレス入力は必須です!';
    }

    # url 欄のスキーマを補完
    if(length $form->{'url'}){
	unless($form->{'url'} =~ m/^http/){
	    $form->{'url'} = 'http://' . $form->{'url'};
	}
    }

    unless($form->{'x-tg-priority'}){
	push @err, '優先度を選んでください.';
    }

    unless(grep(/^cat_/, keys %$form)){
	push @err, '分類を選んでください.';
    }

    my @d = split(/\n/, $form->{'desc'});
    unless(scalar(@d)){
	push @err, 'メッセージを何か書いてください.';
    }elsif(scalar(grep(/^>/, @d)) == scalar(@d)){
	push @err, 'メッセージに引用文しか入っていません.';
    }

    @err;
}

################################################################
# 入力エラーを列記する
################################################################
sub list_input_errors{
    local($_);
    my @err = @_;

    print q{<h3 class="error">入力内容にエラーがあります</h2>};

    print '<ul>';

    for(@err){
	print "<li>$_</li>";
    }

    print '</ul>';
}

################################################################
# ある BR を処理
################################################################
sub display_br{
    my $last = shift;
    my $form = shift;
    my @br = @_;

    TG::print_page_header("BTS$form->{'NO'}: $last->{'subject'}");


    # 単に BR を表示するだけだ。
    TG::print_report($last);
    TG::print_log(\@br);
    print q{<h2>リプライする</h2>
	<p>
	    この件について、提案・意見・返答などありましたら、
	    下の記入欄を使ってリプライしてください。<br>
	    返答の際に、状態・優先度・分類先などは、必要に応じて
	    判断して変更してください。
	</p>};
    TG::print_message_form($last, $form);
}

################################################################
# 指定のハッシュに収められた、ある BR の最新状況を表示する
################################################################
sub print_report{
    my $last = shift;

    print '<h2>最新状況</h2>';
    print qq{<table>};

    print qq{<tr><td bgcolor="$color3">状態</td>};
    print qq{<td bgcolor="$color1">};
    print &TG::pretty($last->{'x-tg-status'}), '</td></tr>';

    print qq{<tr><td bgcolor="$color3">優先度</td>};
    print qq{<td bgcolor="$color1">};
    print &TG::pretty($last->{'x-tg-priority'}), '</td></tr>';

    print qq{<tr><td bgcolor="$color3">分類</td>};
    print qq{<td bgcolor="$color1">};
    print join(', ', grep(s|$_|$categories_table{$_}|,
			  split(/\s/, $last->{'x-tg-category'})));
    print '</td></tr>';

    print qq{<tr><td bgcolor="$color3">最初の報告</td>};
    print qq{<td bgcolor="$color1">$last->{'firstfrom'} };
    print qq{<small>($last->{'firstdate'})</small></td></tr>};

    print qq{<tr><td bgcolor="$color3">最後のリプライ</td>};
    print qq{<td bgcolor="$color1">$last->{'lastfrom'} };
    print qq{<small>($last->{'lastdate'})</small></td></tr>};

    print qq{<tr><td bgcolor="$color3">対象者</td>};
    print qq{<td bgcolor="$color1">};
    if(length $last->{'to'}){
	print $last->{'to'};
    }else{
	print '未定';
    }
    print '</td></tr>';

    print qq{<tr><td bgcolor="$color3">マイルストーン</td>};
    print qq{<td bgcolor="$color1">};
    if($last->{'x-tg-milestone'}){
	print "$last->{'x-tg-milestone'}</td></tr>";
    }else{
	print 'なし</td></tr>';
    }

    print qq{<tr><td bgcolor="$color3">URL</td>};
    if(length $last->{'x-tg-url'}){
	print qq{<td bgcolor="$color1"><a href="$last->{'x-tg-url'}">$last->{'x-tg-url'}</a></td></tr>};
    }else{
	print qq{<td bgcolor="$color1">なし</td></tr>};
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

    print '<h2>ログ</h2>';

    print '<p>全部で ', $#$br+1, ' 件のメッセージがあります.</p>';

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

	# ステータス変更があれば表示
	if($i != 0){
	    my @buf;

	    if($b->{'to'} && $to ne $b->{'to'}){
		if($to){
		    push @buf, "<small>対象者が <b>$to</b> から<br><b>$b->{'to'}</b> に変更されました<br></small>";
		}else{
		    push @buf, "<small>対象者が <b>$b->{'to'}</b> に設定されました<br></small>";
		}
		$to = $b->{'to'};
	    }

	    if($b->{'x-tg-milestone'}){
		if($milestone ne $b->{'x-tg-milestone'}){
		    if($milestone){
			push @buf, qq{
			    <small>マイルストーンが <b>$milestone</b> から
				<b>$b->{'x-tg-milestone'}</b>
			    に変更されました</small>};
		    }else{
			push @buf, qq{
			    <small>マイルストーンが <b>$b->{'x-tg-milestone'}</b>
			    に設定されました</small>};
		    }
		    $milestone = $b->{'x-tg-milestone'};
		}
	    }

	    if($b->{'x-tg-url'}){
		if($url ne $b->{'x-tg-url'}){
		    if($url){
			push @buf, "<small>URL が <b>$url</b> から
                           <br><b>$b->{'x-tg-url'}</b> に変更されました<br></small>";
		    }else{
			push @buf, "<small>URL が <b>$b->{'x-tg-url'}</b> に設定されました<br></small>";
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

	# メッセージを化粧して表示
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
		    <b>マイルストーン</b>: $b->{'x-tg-milestone'}<br>
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
    TG::print_page_header('リプライ');
    TG::commit_br($msg, $form);
}

sub commit_br{
    my $msg = shift;
    my $form = shift;

    if(my @err = TG::check_submitted_form($form)){
	# 書き直し
        TG::list_input_errors(@err);
	TG::print_message_form($msg, $form);
	exit;
    }

    # 新規記事番号を発生させ、ファイルに保存し、メールする。
    # TODO: 以下の処理、だぶるといけないのでロックすべき
    {
	print '<P>処理中です。しばらくお待ちください。</P>';

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
	    <h2>送信・記録が完了しました。</h2>
	    <p>担当者たちにメールも送信されました.</p>
	    <p><a href="${TG::top_uri}/?NO=$form->{'NO'}">
	    <b>報告番号 BTS$form->{'NO'}: $form->{'subject'}</b>
	    の更新結果を見る</a><br>
	    <a href="$top_uri/">TrackGuy トップページへ</a></p>
	    };
}

################################################################
# 新規メッセージを書く
################################################################
sub compose_br{
    my $form = shift;
    my %msg;
    $msg{'x-tg-status'} = 'suggested';
    
    TG::print_page_header('新規メッセージ');

    if(defined $form->{'submit'}){
	# すでに記入された状態でここに来たのなら、
	# 内容をチェックする
        TG::commit_br(\%msg, $form);
	exit;
    }

    print q{
	<h2>新規メッセージ</h2>
	<p>
	    下の記入欄を使って、提案・意見を書いてください。
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
