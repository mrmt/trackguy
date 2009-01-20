# -*- perl -*-
# TrackGuy / TG / Mail.pm
# $Id: TGMail.pm,v 1.1 2000/11/05 21:01:47 morimoto Exp $
use Jcode;
package TG::Mail;
use strict;

use vars qw($VERSION);
$VERSION = '1.00';

################################################################
# TGMail ���饹�Υ��֥������Ȥ򿷵��������롣
sub new{
    my $this = {};
    my $type = shift;
    my %params = @_;
    local($_);

    $this->{'To'} = $params{'To'};
    $this->{'Errors-To'} = $params{'Errors-To'} || $TG::errors_to;
    $this->{'Reply-To'} = $params{'Reply-To'};
    $this->{'CC'} = $params{'CC'};
    $this->{'From'} = $params{'From'} || $TG::default_from;
    $this->{'Charset'} = $params{'Charset'} || $TG::default_charset;
    $this->{'Subject'} = $params{'Subject'} || $TG::default_subject;
    $this->{'Subject'} = Jcode->new($this->{'Subject'})->jis->mime_encode;

    for(keys %params){
	if(/^X-/){
	    $this->{$_} = $params{$_};
	}
    }

    bless $this, $type;
    $this;
}

################################################################
# �إå����ɲ�
sub header{
    my $this = shift;
    my %params = @_;
    my $key;
    for $key(keys %params){
	$this->{$key} = $params{$key};
    }
}

################################################################
# (�����᥽�å�) �����Ƥ�Ǥ���֥᡼���Ф��פȡ�
# �ºݤˤ�ȯ������ʤ��ǡ�stdout �� HTML �� PRE �ǽФ�
sub fakemail{
    my $this = shift;
    $this->{'Fakemail'} = 1;
}

################################################################
# �᡼������������֤�
sub compose{
    my $this = shift;
    my @buf;
    local($_);


    push @buf, "From: $this->{'From'}\n";
    push @buf, "To: $this->{'To'}\n";
    push @buf, "Subject: $this->{'Subject'}\n";
    push @buf, "Reply-To: $this->{'Reply-To'}\n"
	if length $this->{'Reply-To'};
    push @buf, "CC: $this->{'CC'}\n"
	if length $this->{'CC'};
    push @buf, "Errors-To: $this->{'Errors-To'}\n"
	if length $this->{'Errors-To'};
    push @buf, "Precedence: junk\n";
    push @buf, "Mime-Version: 1.0\n";
    push @buf, "X-Mailer: TrackGuy\n";

    for(sort keys %$this){
	if(/^X-/){
	    push @buf, "$_: $this->{$_}\n";
	}
    }

    push @buf, "Content-Type: text/plain; charset=$this->{Charset}\n";

    push @buf, "\n";
    push @buf, Jcode->new($this->{'Body'})->jis;
    push @buf, "\n";

    join('', @buf);
}

################################################################
# �᡼����ʸ���Խ񤯥᥽�åɡ�
# ����Ū�ˤϡ��᡼����ʸ�ˤʤ뤿���ʸ����Хåե��˰���ɲä���
sub print{
    my $this = shift;
    $this->{'Body'} .= shift;
}

################################################################
# �᡼�����������
sub send{
    my $this = shift;
    unless($this->{'Sent'}){
	my $mail = &compose($this);

	if($this->{'Fakemail'}){
	    print '<PRE><SMALL>';
	    print $mail;
	    print '</SMALL></PRE>';
	}else{
	    my $recipient = $this->{'To'} || $this->{'CC'};
	    open(SENDMAIL, "| $TG::mta $recipient");
	    print SENDMAIL $mail;
	    close(SENDMAIL);
	}
	$this->{'Sent'} = 1;
    }
}

################################################################
# TGMail ���֥������ȤΥǥ��ȥ饯����
# �ǥ��ȥ饯���Ǥ� send �᥽�åɤ򥳡��뤹��Τǡ��Ф�˺�줬�ʤ�.
sub DESTROY{
    my $this = shift;
    &send($this);
}

1;

__END__

=head1 NAME

TGMail - Perl CGI �ѥ᡼�����Х��饹

=head1 SYNOPSIS

  use TGMail;
  my $m = TGMail->new('To' => 'webmaster@foo.co.jp',
                         'Subject' => 'Hi, webmaster!');
  $m->print('�ʤ�Ȥ�����Ȥ�');

=head1 ABSTRACT

���Υ饤�֥���, Perl CGI ������ץȤ���, ���ܸ�Υ᡼������������
�˻Ȥ����Ȥ��Ǥ���.

�ޤ� new �᥽�åɤˤ�, �᡼�������Ѥ� TGMail ���饹�Υ��֥������Ȥ�
���.

���֥������Ȥ�������ʤɤΥ᡼���°����, new �ǥ��֥������Ȥ��������
�Ȥ��˻��ꤷ�Ƥ���. �������Ƥ�����°�����ɲä��뤳�Ȥ� ���ϤǤ��ʤ���

������, ���֥������Ȥ��Ф���, print �᥽�åɤ�Ȥä�, ��ʸ��ɤ�ɤ���
�ä��Ƥ���. ��ʸ���ɲä���Ȥ���ʸ��������(����饯�����å�)��, �Ĥޤ� 
print �᥽�åɤΰ�����, �Ҥ��Ƥ� TGMail ���饹��ƤӽФ� Perl �������
�Ȥ� EUC �ޤ��� JIS ������(iso-2022-jp) �ǽ񤫤�Ƥ���ɬ�פ�����.  ��
�ݤ��Żҥ᡼���, ��ưŪ�� iso-2022-jp ���Ѵ���������������.

TGMail ���֥������Ȥ�, ���Ǥ�������, ��ʬ��������ޤ줿�᡼�����Ƥ���
�����Ƥ�����Ǥ���.

=head1 DESCRIPTION

=head2 TGMail ���֥������Ȥκ���

my $m = TGMail->new('To' => 'webmaster@foo.co.jp',
                       'Charset' => 'us-ascii');
                       'Subject' => 'Hello!');

�Ȥ��ä��褦��, new �᥽�åɤΰ�����, ʣ���Υϥå���������, �᡼���
������ʤ�°������ꤹ��. ����ν��������ʤ�. ����Ǥ���°���ϰʲ�
���̤�:

=item To

�᡼������������ꤹ��. To �λ���Ͼ�ά�Ǥ��ʤ�.

=item Subject

���֥������Ȥ���ꤹ��. ��ά���Υǥե���Ȥ� $default_subject �ѿ�����
��.

=item From

�᡼���ȯ���Ԥ���ꤹ��. ��ά���Υǥե���Ȥ� $default_from �ѿ�����
��. ����ϥ᡼��إå������� From: (������ UNIX From) ���Ѥ�����.

=item Reply-To

Reply-To ����ꤹ��. ��ά��ǽ.

=item Errors-To

Errors-To ����ꤹ��. ��ά���Υǥե���Ȥ� $errors_to �ѿ�������.

=item Charset

�᡼��ܥǥ��Υ���饯�����åȤ���ꤹ��. ��ά���Υǥե���Ȥ� 
$default_charset �ѿ�������. ���ܸ��򤵤ʤ����ؤ��������ˤ� 
us-ascii �ʤɤ���ꤹ�٤��Ǥ���.

=item X-�إå�

X- �ǤϤ��ޤ�Ǥ�դ�̾���Υإå�.

=head2 �إå����Ǥ��ɲ�

$m->header('X-Mailer' => 'FooMailer 1.2');

̵̾�ϥå���ǻ��ꤹ�롣

=head2 ��ʸ�λ���

$m->print(ʸ����);

ʸ�����᡼����ʸ���ɲä���. ����Ƥ�Ǥ⹽��ʤ�. �缡��ʸ���ɲä���
��. ����饯�����åȤ� EUC �ޤ��� iso-2022-jp �Τ���.

=head2 �᡼�������

TGMail ���֥������Ȥ�, ���Ǥ�������, ��ʬ��������ޤ줿�᡼�����Ƥ���
�����Ƥ�����Ǥ���. �������ä�, ���֥������Ȥ��ä�, ��ʸ��ɤ�ɤ���
�ä�����, ���Ȥ����äƤ����Ƥ�褤. �������ξ��᡼�뤬���������Τ�
���֥������Ⱦ��ǤΥ����ߥ󥰤ˤʤ뤫��, ���줬���ޤ����ʤ����Τۤ���
¿��������

����Ū��������Ԥʤ��ˤ�, send �᥽�åɤ��Ѥ���.

$m->send;

��� send �᥽�åɤ�������Ԥʤ���, ���� TGMail ���֥������Ȥϡ�������
�ߡפȤ���, ���� send �᥽�åɤ�Ƥ�Ǥ������ϹԤʤ��ʤ�.  ̵��, ��
�Υ��֥������Ⱦ��Ǥκݤ������ϹԤʤ��ʤ�.

=head2 �ǥХå���ǽ

$m->fakemail;

fakemail �᥽�åɤ�Ƥ֤�, �᡼��ϼºݤ��������줺, <PRE> �����ǰϤ�
��ɸ����Ϥ˽Ф뤿��, CGI Script �ν��ϤȺ����ä� Web �֥饦�����̤˽�
�뤳�ȤǤ���.

=head1 BUGS

���Υޥ˥奢��� perldoc �Ǥϸ����ʤ��Τ�, ��ɤ��Τޤ��ɤष������ޤ���.

=head1 SEE ALSO

=cut
