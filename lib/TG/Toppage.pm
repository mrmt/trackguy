# -*- perl -*-
# TrackGuy / TG / Toppage.pm
# $Id: TGMail.pm,v 1.1 2000/11/05 21:01:47 morimoto Exp $
package TG::Toppage;
# use strict;

# データを分類して配列につっこむ
# それぞれの BR の最終(最新)ステータスを配列に格納する
my(@subject, @firstdate, @lastdate, @firstfrom, @lastfrom, @milestone,
   @priority, @to, @url, @status, @nreply, @category);

################################################################
# トップページ表示
################################################################
sub print{
    my $form = shift;

    TG::print_page_header($TG::title);
    print $TG::issue;

    unless(keys %$form){
	# 無指定で来たなら前フリをいれとく
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

	# 表示すべきカテゴリが指定されていた場合
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

    # 絞込み指定パネルを出す
    &show_commander(%$form);

    # 絞り込み指定がない場合は、デフォルトの絞り込みトピックを出す
    unless(keys %$form){

	print '<h2>本日のトピック</h2>';

	print '<h3>優先度が緊急なのに終わっていないもの</h3>';
	&display({'PR' => ['critical'],
		  'ST' => ['suggested', 'scheduled', 'reserved'],
		  'CAPTION' => '大急ぎでやろう!',
		  'BGCOLOR' => '#FF0000',
		  'COLOR' => '#FFFFFF'});

	print '<h3>優先度が重要なのに終わっていないもの</h3>';
	&display({'PR' => ['high'],
		  'ST' => ['suggested', 'scheduled', 'reserved'],
		  'CAPTION' => 'やりましょうね!',
		  'BGCOLOR' => '#FFCC00'});

	print '<h3>提案されたままのもの</h3>';
	&display({'ST' => ['suggested'],
		  'CAPTION' => '提案されたままのものは
		放置状態にあるといえます.<BR>
		担当者を振るなり、自分が引き受けるなり、
		せめてきちんと「却下」にしましょう。',
		    'BGCOLOR' => '#FFCC00'});

	# TODO
	if(0){
	    print '<H3>そろそろですよ? マイルストーンが近いもの Top 10</H3>';
	    print q{
		<tr><td bgcolor="#ffcc00" colspan=5>
		    忘れてませんか? 遅れていませんか?
		};

	    print qq{<tr><td bgcolor="$TG::color1"><small>};
	    print '(これから作ります)';
	    print '</small></td></tr>';
	}

    }else{
	# さもなくば、ユーザが指定した絞込み条件でリストを表示
	print '<h2>絞り込まれたリスト</h2>';
	&display({'PR' => [split($;, $form->{'PR'})],
		  'ST' => [split($;, $form->{'ST'})],
		  'CA' => [split($;, $form->{'CA'})],
		  'PERSON' => [split($;, $form->{'PERSON'})]});
    }

    # 関係者別リスト
    {
	my(%person, $nperson, $nrow, $row);

	print '<h2>関係者別リスト</h2>';

	for(@to){
	    for(split(/[\s,]/)){
		$person{$_}++;
	    }
	}
	for(@firstfrom){
	    $person{$_}++;
	}

	unless(keys %person){
	    print '(ありません)';
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
# 指定に基づいて絞り込んだ BR リストを表示
################################################################
sub display{
    my $arg = shift;

    # どの br を表示するか、対象となる BR のインデクスを詰める配列
    my %display;

    # 条件に合わせて絞り込んでいく
    # まずは全リストをハッシュの種に放り込む
    for my $i (0 .. $#status){
	if($status[$i]){
	    $display{$i}++;
	}
    }

    # 状態で絞り込む
    if($arg->{'ST'}){
	my $regex = '(' . join('|', @{$arg->{'ST'}}) . ')';
	for my $i (keys %display){
	    if($status[$i] !~ /$regex/){
		delete $display{$i};
	    }
	}
    }

    # 優先度で絞り込む
    if($arg->{'PR'}){
	my $regex = '(' . join('|', @{$arg->{'PR'}}) . ')';
	for my $i (keys %display){
	    if($priority[$i] !~ /$regex/){
		delete $display{$i};
	    }
	}
    }

    # カテゴリで絞り込む
    if($arg->{'CA'}){
	my $regex = '(' . join('|', @{$arg->{'CA'}}) . ')';
	for my $i (keys %display){
	    if($category[$i] !~ /$regex/){
		delete $display{$i};
	    }
	}
    }

    # 人で絞り込む
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
	print '分類: ';
	print join(', ', grep(s/$_/$TG::categories_table{$_}/,
			      split(/\n/, $arg->{'CA'})));
	print ' | ';
    }

    if(@{$arg->{'PERSON'}}){
	print '関係者: <B>';
	print join(', ', @{$arg->{'PERSON'}});
	print ' </B> | ';
    }

    if(@{$arg->{'ST'}}){
	print '状態: ';
	print join(', ', grep(s/$_/TG::pretty($_)/e, @{$arg->{'ST'}}));
	print ' | ';
    }

    if(@{$arg->{'PR'}}){
	print '優先度: ';
	print join(', ', grep(s/$_/TG::pretty($_)/e, @{$arg->{'PR'}}));
	print ' | ';
    }

    print '全 ', scalar(keys %display), '件';
    print '</small>';

    print qq{<tr><th align="left" bgcolor="$TG::color4" width="20"><small>};
    print qq{</small></th><th align="left" bgcolor="$TG::color3" width="50"><small>};
    print '状態';
    print qq{</small></th><th align="left" bgcolor="$TG::color3" width="50"><small>};
    print '重要度';
    print qq{</small></th><th align="left" bgcolor="$TG::color3" width="50"><small>};
    print '題名';
    print qq{</small></th><th align="left" bgcolor="$TG::color3"><small>};
    print '<nobr>分類(部署)</nobr>';
    print qq{</small></th><th align="left" bgcolor="$TG::color3"><small>};
    print '対象者';
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
		print "$nreply[$id] リプライ";
	    }else{
		print "リプライなし";
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
		print ' 〜 ';
		print $lastdate[$id];
		print '</font>';
	    }

	    print '</small></td></tr>';
	}
    }else{
	print qq{<tr><td colspan="6" bgcolor="$TG::color1"><small>};
	print '(ありません)';
	print '</small></td></tr>';
    }
    print "\n";
    print '</table>';
}

################################################################
# 絞込みパネル
################################################################
sub show_commander{
    my $form = shift;
    my $rows = $TG::commander_rows;

    print '<h2>絞り込み指定</h2>';

    print qq{<form action="$TG::top_uri/" method="get">};
    print qq{<table align="center"><tr valign="top">};

    print qq{<td valign="middle" bgcolor="$TG::color3" align="center">状態、優先度、分類など、<br>};
    print '見たい条件を選んで<br>';

    print '<noscript>';
    print '<input type="submit" value="絞り込み"><br>を押して';
    print '</noscript>';

    print 'ください.';
    print '<p><small>(Control キーを押しながら<br>クリックすれば<BR>複数選択できます)</small>';


    print qq{<td bgcolor="$TG::color4">状態<br>};
    print qq{<select name="ST" SIZE="$rows" onchange=\"submit();\" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'ST'};
    print 'value="">(指定しない)</option>';
    for my $s (qw(suggested scheduled reserved rejected done)){
	print '<option ';
	print 'selected ' if $form->{'ST'} =~ /$s/;
	printf 'value="%s">%s</option>', $s, TG::pretty($s);
    }
    print '</select>';

    print qq{<td bgcolor="$TG::color4">優先度<br>};
    print qq{<select name="PR" size="$rows" onchange="submit();" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'PR'};
    print 'value="">(指定しない)</option>';
    for my $s (qw(critical high normal low)){
	print '<option ';
	print 'selected ' if $form->{'PR'} =~ /$s/;
	printf 'value="%s">%s</option>', $s, TG::pretty($s);
    }
    print '</select>';

    print qq{<td bgcolor="$TG::color4">分類(部署)<br>};
    print qq{<select name="CA" size="$rows" onchange="submit();" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'CA'};
    print 'value="">(指定しない)</option>';
    for my $s (sort keys %TG::categories_table){
	print '<option ';
	print 'selected ' if $form->{'CA'} =~ /$s/;
	printf 'value="%s">%s</option>', $s, $TG::categories_table{$s};
    }
    print '</select>';

    print qq{<td bgcolor="$TG::color4">関係者<br>};
    print qq{<select name="person" size="$rows" onchange="submit();" multiple>};
    print '<option ';
    print 'selected ' unless $form->{'PERSON'};
    print 'value="">(指定しない)</option>';

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
# 記事番号の入った配列を、状態、重要度の順に重みをつけてソート
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
