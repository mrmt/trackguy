# -*- perl -*-
# TrackGuy / TG / Mail.pm
# $Id: TGMail.pm,v 1.1 2000/11/05 21:01:47 morimoto Exp $
use Jcode;
package TG::Mail;
use strict;

use vars qw($VERSION);
$VERSION = '1.00';

################################################################
# TGMail クラスのオブジェクトを新規生成する。
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
# ヘッダを追加
sub header{
    my $this = shift;
    my %params = @_;
    my $key;
    for $key(keys %params){
	$this->{$key} = $params{$key};
    }
}

################################################################
# (隠しメソッド) これを呼んでから「メールを出す」と、
# 実際には発信されないで、stdout に HTML の PRE で出る
sub fakemail{
    my $this = shift;
    $this->{'Fakemail'} = 1;
}

################################################################
# メールを生成して返す
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
# メール本文を一行書くメソッド。
# 具体的には、メール本文になるための文字列バッファに一行追加する
sub print{
    my $this = shift;
    $this->{'Body'} .= shift;
}

################################################################
# メールを送信する
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
# TGMail オブジェクトのデストラクタ。
# デストラクタでも send メソッドをコールするので、出し忘れがない.
sub DESTROY{
    my $this = shift;
    &send($this);
}

1;

__END__

=head1 NAME

TGMail - Perl CGI 用メール送出クラス

=head1 SYNOPSIS

  use TGMail;
  my $m = TGMail->new('To' => 'webmaster@foo.co.jp',
                         'Subject' => 'Hi, webmaster!');
  $m->print('なんとかかんとか');

=head1 ABSTRACT

このライブラリは, Perl CGI スクリプトから, 日本語のメールを送信するの
に使うことができる.

まず new メソッドにて, メール送信用の TGMail クラスのオブジェクトを
作る.

サブジェクトや送信先などのメールの属性は, new でオブジェクトを作成する
ときに指定しておく. 作成してから後で属性を追加することは 今はできない。

そして, オブジェクトに対して, print メソッドを使って, 本文をどんどん追
加していく. 本文を追加するときの文字コード(キャラクタセット)は, つまり 
print メソッドの引数は, ひいては TGMail クラスを呼び出す Perl スクリプ
トは EUC または JIS コード(iso-2022-jp) で書かれている必要がある.  実
際の電子メールは, 自動的に iso-2022-jp に変換されて送信される.

TGMail オブジェクトは, 消滅する前に, 自分に貯め込まれたメール内容を送
信してから消滅する.

=head1 DESCRIPTION

=head2 TGMail オブジェクトの作成

my $m = TGMail->new('To' => 'webmaster@foo.co.jp',
                       'Charset' => 'us-ascii');
                       'Subject' => 'Hello!');

といったように, new メソッドの引数に, 複数のハッシュを入れて, メールの
送信先など属性を指定する. 指定の順序は問われない. 指定できる属性は以下
の通り:

=item To

メールの送信先を指定する. To の指定は省略できない.

=item Subject

サブジェクトを指定する. 省略時のデフォルトは $default_subject 変数の内
容.

=item From

メールの発信者を指定する. 省略時のデフォルトは $default_from 変数の内
容. これはメールヘッダに入る From: (いわゆる UNIX From) に用いられる.

=item Reply-To

Reply-To を指定する. 省略可能.

=item Errors-To

Errors-To を指定する. 省略時のデフォルトは $errors_to 変数の内容.

=item Charset

メールボディのキャラクタセットを指定する. 省略時のデフォルトは 
$default_charset 変数の内容. 日本語を解さない相手への送信時には 
us-ascii などを指定すべきである.

=item X-ヘッダ

X- ではじまる任意の名前のヘッダ.

=head2 ヘッダ要素の追加

$m->header('X-Mailer' => 'FooMailer 1.2');

無名ハッシュで指定する。

=head2 本文の指定

$m->print(文字列);

文字列をメール本文に追加する. 何回呼んでも構わない. 順次本文に追加され
る. キャラクタセットは EUC または iso-2022-jp のこと.

=head2 メールの送信

TGMail オブジェクトは, 消滅する前に, 自分に貯め込まれたメール内容を送
信してから消滅する. したがって, オブジェクトを作って, 本文をどんどん追
加したら, あとは放っておいてもよい. ただその場合メールが送信されるのは
オブジェクト消滅のタイミングになるから, これが好ましくない場合のほうが
多いだろう。

明示的に送信を行なうには, send メソッドを用いる.

$m->send;

一回 send メソッドで送信を行なうと, その TGMail オブジェクトは「送信済
み」とされ, 再度 send メソッドを呼んでも送信は行なわれない.  無論, そ
のオブジェクト消滅の際も送信は行なわれない.

=head2 デバッグ機能

$m->fakemail;

fakemail メソッドを呼ぶと, メールは実際に送信されず, <PRE> タグで囲ん
で標準出力に出るため, CGI Script の出力と混ざって Web ブラウザ画面に出
ることであろう.

=head1 BUGS

このマニュアルは perldoc では見られないので, 結局このまま読むしかありません.

=head1 SEE ALSO

=cut
