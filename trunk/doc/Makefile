# doc/Makefile

all: trackguy.txt trackguy.html
trackguy.txt: trackguy.sgml
	sgml2txt -f -l ja -c nippon trackguy.sgml
trackguy.html: trackguy.sgml
	sgml2html -l ja -c nippon trackguy.sgml
clean:
	rm -f trackguy-*.html trackguy.html trackguy.txt

# EOF
