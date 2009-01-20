#
# TrackGuy / Makefile
# $Id: Makefile,v 1.3 2000/11/05 21:05:48 morimoto Exp $
#
# TrackGuy �� namazu �ˤ�븡���򤫤�������Ѥ��� Makefile �Υ���ץ�.
# cron �ʤɤ������Ū�˼¹Ԥ�����ʤɤ˻ȤäƤ�������.

.PHONY: index

MKNMZ		=	mknmz

# namazu 1.x �ξ��
MKNMZ_OPT	=	-ah -l ja -t '\d\d\d\d\d'

# namazu �Υ���ǥ����ե����뤬���ޤ륵�֥ǥ��쥯�ȥ�
INDEX_DIR	=	index

# TrackGuy �Υǡ����������ޤ륵�֥ǥ��쥯�ȥ�
DATA_DIR	=	data

# ����ǥ����󥰤�Ԥ�
index:
	mkdir -p $(INDEX_DIR)
	cp lib/NMZ.* $(INDEX_DIR)
	$(MKNMZ) $(MKNMZ_OPT) -O $(INDEX_DIR) $(DATA)

# ����ǥ����ǡ�����õ��
clean:
	rm -f $(INDEX_DIR)/*

# EOF
