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
$| = 1;   # �Хåե���󥰤��ʤ�

print "Content-Type: text/html; charset=euc-jp\r\n\r\n";

# Query ���äƤ���
my %form = TG::parse_form_data;

# ������å����������������֤ʤ�..
if(defined $form{'NEW'}){
    TG::compose_br(\%form);
    exit;
}

# ���� BR ��ɽ��������֤ʤ�..
if(defined $form{'NO'}){

    # ���� BR ������å�����������˼���
    my @br = TG::read_br($form{'NO'});
    unless(@br){
        TG::print_page_header('�ǡ����۾�');
	print qq{
	    <p>
	    �Х���ݡ����ֹ� $form{'NO'} �Υǡ��������꤬����ޤ���
	    �����Ԥˤ�Ϣ����������
	    </p>
	};
	exit;
    }

    # ���� BR �κǸ��(�ǿ���)��å������ξ��֤� �����Τܤä�Ĵ�٤�
    my %lastmsg = TG::get_last_message($form{'NO'}, @br);

    # ��å������� Submit ������̤Ȥ��Ƥ������褿���ν���
    if($form{'submit'}){
        TG::submit_br(\%lastmsg, \%form);
	exit;
    }

    TG::display_br(\%lastmsg, \%form, @br);
    exit;
}

# ɽ���䥢���������Ф��벿�λ����ʤ��Τǡ�
# �ȥåץڡ�����ɽ�����褦
TG::Toppage::print(\%form);
exit;

__END__
