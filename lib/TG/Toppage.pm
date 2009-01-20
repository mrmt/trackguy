# -*- perl -*-
# TrackGuy / TG / Toppage.pm
# $Id: TGMail.pm,v 1.1 2000/11/05 21:01:47 morimoto Exp $
package TG::Toppage;
# use strict;

# �ǡ�����ʬ�ष������ˤĤä���
# ���줾��� BR �κǽ�(�ǿ�)���ơ�����������˳�Ǽ����
my(@subject, @firstdate, @lastdate, @firstfrom, @lastfrom, @milestone,
   @priority, @to, @url, @status, @nreply, @category);

################################################################
# �ȥåץڡ���ɽ��
################################################################
sub print{
    my $form = shift;

    TG::print_page_header($TG::title);
    print $TG::issue;

    unless(keys %$form){
	# ̵������褿�ʤ����ե�򤤤�Ȥ�
	print $TG::motd;
    }

    for my $br_id (TG::br_list){
	my @mes = TG::read_br($br_id);

	my $to = $mes[0]{'to'};
	my $category = $mes[0]{'x-tg-category'};
	my $milestone = $mes[0]{'x-tg-milestone'};
	my $priority = $mes[0]{'x-tg-priority'};
	my $url = $mes[0]{'x-tg-url'};
	my $status = $mes[0]{'x-tg-status'};

	for my $i (1 .. $#mes){
	    my $b = $mes[$i];
	    $to = $b->{'to'} if length $b->{'to'};
	    $category = $b->{'x-tg-category'} if length $b->{'x-tg-category'};
	    $milestone = $b->{'x-tg-milestone'} if length $b->{'x-tg-milestone'};
	    $priority = $b->{'x-tg-priority'} if length $b->{'x-tg-priority'};
	    $url = $b->{'x-tg-url'} if length $b->{'x-tg-url'};
	    $status = $b->{'x-tg-status'} if length $b->{'x-tg-status'};
	}

	# ɽ�����٤����ƥ��꤬���ꤵ��Ƥ������
	if(length $form->{'CA'}){
	    unless($category =~ /$form->{'CA'}/){
		next;
	    }
	}

	$nreply[$br_id] = $#mes;
	$subject[$br_id] = $mes[0]{'subject'};
	$firstdate[$br_id] = $mes[0]{'date'};
	$lastdate[$br_id] = $mes[$#mes]{'date'};
	$firstfrom[$br_id] = $mes[0]{'from'};
	$lastfrom[$br_id] = $mes[$#mes]{'from'};
	$category[$br_id] = $category;
	$milestone[$br_id] = $milestone;
	$priority[$br_id] = $priority;
	$to[$br_id] = $to;
	$url[$br_id] = $url;
	$status[$br_id] = $status;
    }

    # �ʹ��߻���ѥͥ��Ф�
    &show_commander(%$form);

    # �ʤ���߻��꤬�ʤ����ϡ��ǥե���Ȥιʤ���ߥȥԥå���Ф�
    unless(keys %$form){

	print '<h2>�����Υȥԥå�</h2>';

	print '<h3>ͥ���٤��۵ޤʤΤ˽���äƤ��ʤ����</h3>';
	&display({'PR' => ['critical'],
		  'ST' => ['suggested', 'scheduled', 'reserved'],
		  'CAPTION' => '��ޤ��Ǥ��!',
		  'BGCOLOR' => '#FF0000',
		  'COLOR' => '#FFFFFF'});

	print '<h3>ͥ���٤����פʤΤ˽���äƤ��ʤ����</h3>';
	&display({'PR' => ['high'],
		  'ST' => ['suggested', 'scheduled', 'reserved'],
		  'CAPTION' => '���ޤ��礦��!',
		  'BGCOLOR' => '#FFCC00'});

	print '<h3>��Ƥ��줿�ޤޤΤ��</h3>';
	&display({'ST' => ['suggested'],
		  'CAPTION' => '��Ƥ��줿�ޤޤΤ�Τ�
		���־��֤ˤ���Ȥ����ޤ�.<BR>
		ô���Ԥ򿶤�ʤꡢ��ʬ������������ʤꡢ
		����Ƥ�����ȡֵѲ��פˤ��ޤ��礦��',
		    'BGCOLOR' => '#FFCC00'});

	# TODO
	if(0){
	    print '<H3>������Ǥ���? �ޥ��륹�ȡ��󤬶ᤤ��� Top 10</H3>';
	    print q{
		<tr><td bgcolor="#ffcc00" colspan=5>
		    ˺��Ƥޤ���? �٤�Ƥ��ޤ���?
		};

	    print qq{<tr><td bgcolor="$TG::color1"><small>};
	    print '(���줫����ޤ�)';
	    print '</small></td></tr>';
	}

    }else{
	# ����ʤ��С��桼�������ꤷ���ʹ��߾��ǥꥹ�Ȥ�ɽ��
	print '<h2>�ʤ���ޤ줿�ꥹ��</h2>';
	&display({'PR' => [split($;, $form->{'PR'})],
		  'ST' => [split($;, $form->{'ST'})],
		  'CA' => [split($;, $form->{'CA'})],
		  'PERSON' => [split($;, $form->{'PERSON'})]});
    }

    # �ط����̥ꥹ��
    {
	my(%person, $nperson, $nrow, $row);

	print '<h2>�ط����̥ꥹ��</h2>';

	for(@to){
	    for(split(/[\s,]/)){
		$person{$_}++;
	    }
	}
	for(@firstfrom){
	    $person{$_}++;
	}

	unless(keys %person){
	    print '(����ޤ���)';
	}

	print '<table align=center><tr valign=top><td>';
	$nperson = keys %person;
	$nrow = int($nperson / 3);

	for(sort keys %person){
	    next unless length $_;
	    print qq{<a href="index.cgi?PERSON=$_">$_</A>
			 <small>($person{$_})</small><br>};
	    if(++$row > $nrow){
		print '</td><td>';
		$row = 0;
	    }
	}
	print '</td></tr></table>';
    }
}

################################################################
# ����˴�Ť��ƹʤ����� BR �ꥹ�Ȥ�ɽ��
################################################################
sub display{
    my $arg = shift;

    # �ɤ� br ��ɽ�����뤫���оݤȤʤ� BR �Υ���ǥ�����ͤ������
    my %display;

    # ���˹�碌�ƹʤ����Ǥ���
    # �ޤ������ꥹ�Ȥ�ϥå���μ���������
    for my $i (0 .. $#status){
	if($status[$i]){
	    $display{$i}++;
	}
    }

    # ���֤ǹʤ����
    if($arg->{'ST'}){
	my $regex = '(' . join('|', @{$arg->{'ST'}}) . ')';
	for my $i (keys %display){
	    if($status[$i] !~ /$regex/){
		delete $display{$i};
	    }
	}
    }

    # ͥ���٤ǹʤ����
    if($arg->{'PR'}){
	my $regex = '(' . join('|', @{$arg->{'PR'}}) . ')';
	for my $i (keys %display){
	    if($priority[$i] !~ /$regex/){
		delete $display{$i};
	    }
	}
    }

    # ���ƥ���ǹʤ����
    if($arg->{'CA'}){
	my $regex = '(' . join('|', @{$arg->{'CA'}}) . ')';
	for my $i (keys %display){
	    if($category[$i] !~ /$regex/){
		delete $display{$i};
	    }
	}
    }

    # �ͤǹʤ����
    if($arg->{'PERSON'}){
	my $regex = '(' . join('|', @{$arg->{'PERSON'}}) . ')';
	for my $i (keys %display){
	    if($to[$i] !~ /$regex/ && $firstfrom[$i] !~ /$regex/){
		delete $display{$i};
	    }
	}
    }

    print qq{<table align="center">};

    if($arg->{'CAPTION'}){
	print '<tr><td ';
	print "bgcolor=$arg->{'BGCOLOR'} " if $arg->{'BGCOLOR'};
	print 'colspan="6">';
	print "<font color=$arg->{'COLOR'}>" if $arg->{'COLOR'};
	print $arg->{'CAPTION'};
	print "</font>" if $arg->{'COLOR'};
	print '</td></tr>';
    }

    print qq{<tr><td bgcolor="$TG::color4" colspan="6">};
    print '<font color="#ffffff">';
    print '<small>';

    if(@{$arg->{'CA'}}){
	print 'ʬ��: ';
	print join(', ', grep(s/$_/$TG::categories_table{$_}/,
			      split(/\n/, $arg->{'CA'})));
	print ' | ';
    }

    if(@{$arg->{'PERSON'}}){
	print '�ط���: <B>';
	print join(', ', @{$arg->{'PERSON'}});
	print ' </B> | ';
    }

    if(@{$arg->{'ST'}}){
	print '����: ';
	print join(', ', grep(s/$_/TG::pretty($_)/e, @{$arg->{'ST'}}));
	print ' | ';
    }

    if(@{$arg->{'PR'}}){
	print 'ͥ����: ';
	print join(', ', grep(s/$_/TG::pretty($_)/e, @{$arg->{'PR'}}));
	print ' | ';
    }

    print '�� ', scalar(keys %display), '��';
    print '</small>';

    print qq{<tr><th align="left" bgcolor="$TG::color4" width="20"><small>};
    print qq{</small></th><th align="left" bgcolor="$TG::color3" width="50"><small>};
    print '����';
    print qq{</small></th><th align="left" bgcolor="$TG::color3" width="50"><small>};
    print '������';
    print qq{</small></th><th align="left" bgcolor="$TG::color3" width="50"><small>};
    print '��̾';
    print qq{</small></th><th align="left" bgcolor="$TG::color3"><small>};
    print '<nobr>ʬ��(����)</nobr>';
    print qq{</small></th><th align="left" bgcolor="$TG::color3"><small>};
    print '�оݼ�';
    print '</small></th></tr>';

    if(keys %display){
	my $col;

	for my $id (&sort_br(reverse sort keys %display)){
	    $col = $col eq $TG::color1 ? '#dddddd' : $TG::color1;
	    print qq{<tr><td bgcolor="$TG::color4" align="right" width="20">}, $id;

	    print qq{</td><td bgcolor="$col" width="50">};
	    print TG::pretty($status[$id]);

	    print qq{</td><td bgcolor="$col" width="50">};
	    print TG::pretty($priority[$id]);

	    if($milestone[$id]){
		# TODO: icon must be redrawn
		# printf('<BR><IMG SRC="clock.gif" ALT="%s">', $milestone[$id]);
		print "<font size=1>$milestone[$id]</FONT>";
	    }

	    print qq{</td><td bgcolor="$col">};
	    print qq{<a href="${TG::top_uri}/?NO=$id">$subject[$id]</a>};

	    print '<small> (';
	    if($nreply[$id]){
		print "$nreply[$id] ��ץ饤";
	    }else{
		print "��ץ饤�ʤ�";
	    }
	    print ')</small>';

	    print qq{</td><td bgcolor="$col">};
	    print join('<br>', 
		       grep(s/$_/$TG::categories_table{$_}/,
			    sort split(/\s/, $category[$id])));
	    print '</small></td>';

	    print qq{</td><td bgcolor="$col">};
	    {
		my($s) = $to[$id];
		$s =~ s/[,]/ /g;
		print $s || '-';
	    }

	    {
		print '<font size="1" color="#666666"><br>';
		print $firstdate[$id];
		print ' �� ';
		print $lastdate[$id];
		print '</font>';
	    }

	    print '</small></td></tr>';
	}
    }else{
	print qq{<tr><td colspan="6" bgcolor="$TG::color1"><small>};
	print '(����ޤ���)';
	print '</small></td></tr>';
    }
    print "\n";
    print '</table>';
}

################################################################
# �ʹ��ߥѥͥ�
################################################################
sub show_commander{
    my $form = shift;
    my $rows = $TG::commander_rows;

    print '<h2>�ʤ���߻���</h2>';

    print qq{<form action="$TG::top_uri/" method="get">};
    print qq{<table align="center"><tr valign="top">};

    print qq{<td valign="middle" bgcolor="$TG::color3" align="center">���֡�ͥ���١�ʬ��ʤɡ�<br>};
    print '���������������<br>';

    print '<noscript>';
    print '<input type="submit" value="�ʤ����"><br>�򲡤���';
    print '</noscript>';

    print '��������.';
    print '<p><small>(Control �����򲡤��ʤ���<br>����å������<BR>ʣ������Ǥ��ޤ�)</small>';


    print qq{<td bgcolor="$TG::color4">����<br>};
    print qq{<select name="ST" SIZE="$rows" onchange=\"submit();\" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'ST'};
    print 'value="">(���ꤷ�ʤ�)</option>';
    for my $s (qw(suggested scheduled reserved rejected done)){
	print '<option ';
	print 'selected ' if $form->{'ST'} =~ /$s/;
	printf 'value="%s">%s</option>', $s, TG::pretty($s);
    }
    print '</select>';

    print qq{<td bgcolor="$TG::color4">ͥ����<br>};
    print qq{<select name="PR" size="$rows" onchange="submit();" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'PR'};
    print 'value="">(���ꤷ�ʤ�)</option>';
    for my $s (qw(critical high normal low)){
	print '<option ';
	print 'selected ' if $form->{'PR'} =~ /$s/;
	printf 'value="%s">%s</option>', $s, TG::pretty($s);
    }
    print '</select>';

    print qq{<td bgcolor="$TG::color4">ʬ��(����)<br>};
    print qq{<select name="CA" size="$rows" onchange="submit();" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'CA'};
    print 'value="">(���ꤷ�ʤ�)</option>';
    for my $s (sort keys %TG::categories_table){
	print '<option ';
	print 'selected ' if $form->{'CA'} =~ /$s/;
	printf 'value="%s">%s</option>', $s, $TG::categories_table{$s};
    }
    print '</select>';

    print qq{<td bgcolor="$TG::color4">�ط���<br>};
    print qq{<select name="person" size="$rows" onchange="submit();" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'PERSON'};
    print 'value="">(���ꤷ�ʤ�)</option>';

    my %person;
    for(@to){
	for(split(/[\s,]/)){
	    $person{$_}++;
	}
    }
    for(@firstfrom){
	$person{$_}++;
    }
    for(sort keys %person){
	if(length $_){
	    print '<option ';
	    print 'selected ' if $form->{'PERSON'} =~ /$_/;
	    printf 'value="%s">%s</option>', $_, $_;
	}
    }
    print '</select>';
    print '</td></tr></table></form>';
}

################################################################
# �����ֹ�����ä�����򡢾��֡������٤ν�˽Ťߤ�Ĥ��ƥ�����
################################################################
sub sort_br{
    my @s;
    for my $i (@_){
	push @s, sprintf("%d%d\t%d",
			 $TG::label_enum{$status[$i]},
			 $TG::label_enum{$priority[$i]},
			 $i);
    }
    grep(s/.*\t//, reverse sort @s);
}

1;
