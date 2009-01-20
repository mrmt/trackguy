#!/usr/bin/perl
#
# TrackGuy / index.cgi
# $Id: index.cgi,v 1.22 2000/11/05 21:01:47 morimoto Exp $

require 5.005;
use lib qw(lib);
use TG;
use TG::Toppage;
use TG::Mail;
use strict;
END { TG::page_footer; }
$| = 1;   # バッファリングしない

print "Content-Type: text/html; charset=euc-jp\r\n\r\n";

# Query を取ってくる
my %form = TG::parse_form_data;

# 新規メッセージを作成する状態なら..
if(defined $form{'NEW'}){
    TG::compose_br(\%form);
    exit;
}

# 特定 BR を表示する状態なら..
if(defined $form{'NO'}){

    # その BR の全メッセージを配列に取得
    my @br = TG::read_br($form{'NO'});
    unless(@br){
        TG::print_page_header('データ異常');
	print qq{
	    <p>
	    バグレポート番号 $form{'NO'} のデータに問題があります。
	    管理者にご連絡ください。
	    </p>
	};
	exit;
    }

    # その BR の最後の(最新の)メッセージの状態を さかのぼって調べる
    my %lastmsg = TG::get_last_message($form{'NO'}, @br);

    # メッセージを Submit した結果としてここに来た場合の処理
    if($form{'submit'}){
        TG::submit_br(\%lastmsg, \%form);
	exit;
    }

    TG::display_br(\%lastmsg, \%form, @br);
    exit;
}

# 表示やアクションに対する何の指定もないので、
# トップページを表示しよう
TG::Toppage::print(\%form);
exit;

__END__
