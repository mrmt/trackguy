#
# TrackGuy / Makefile
# $Id: Makefile,v 1.3 2000/11/05 21:05:48 morimoto Exp $
#
# TrackGuy で namazu による検索をかける場合に用いる Makefile のサンプル.
# cron などから定期的に実行する場合などに使ってください.

.PHONY: index

MKNMZ		=	mknmz

# namazu 1.x の場合
MKNMZ_OPT	=	-ah -l ja -t '\d\d\d\d\d'

# namazu のインデクスファイルが収まるサブディレクトリ
INDEX_DIR	=	index

# TrackGuy のデータ群が収まるサブディレクトリ
DATA_DIR	=	data

# インデキシングを行う
index:
	mkdir -p $(INDEX_DIR)
	cp lib/NMZ.* $(INDEX_DIR)
	$(MKNMZ) $(MKNMZ_OPT) -O $(INDEX_DIR) $(DATA)

# インデクスデータを消去する
clean:
	rm -f $(INDEX_DIR)/*

# EOF
