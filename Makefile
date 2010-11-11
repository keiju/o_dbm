########################################################################
#
#	Makefile - GNU Makefile for  RUBY and PERL lib.
#	    $Release Version: $
#	    $Revision: 1.2 $
# 	    $Date: 2002/07/11 11:20:06 $
# 	    by Keiju ISHITSUKA(SHL Japan Inc.)
# 
#  --
# 
#
########################################################################
#
#	Definition of Variables
#
POPTS	=	-Plp
ROPTS	=
#
#
#
ACTIVEDIR=	$(HOME)/private/active/ruby/shell
KEEPDIR	=	$(HOME)/var/src/var.lib/ruby/shell

TAR_PREFIX = o_dbm

RB_INSTDIR	=	$(HOME)/var/lib/ruby
PL_INSTDIR	=	$(HOME)/var/lib/perl

RB_SRCS	=	o_dbm.rb

README  =	\
		README.jp \
		test-o_dbm.rb

TESTS	=	$(wildcard test-*.rb)

SRCS	=	$(RB_SRCS)
OBJS	=	$(SRCS)

### Definition of Static Variables #############################################
#
TS	=	TimeStamps
RCS	=	RCS

rb_s    :=	$(filter %.rb, $(RB_SRCS))
pl_s	:=	$(filter %.pl, $(SRCS))
ppl_s	:=	$(filter %.ppl, $(SRCS))

rb_p	:=	$(rb_s)
pl_p	:=	$(pl_s)
ppl_p	:=	$(ppl_s: .ppl=.pl)
#PROGRAMS:=	$(TESTS: .rb=.foo)
PROGRAMS:=	$(patsubst test-%.rb,test/%,$(TESTS))

rb_i	:=	$(rb_s)
pl_i	:=	$(pl_s)
ppl_i	:=	$(ppl_p)
INSTALLS=	$(rb_s) $(pl_i) $(ppl_i)

PRINTFILES=	$(SRCS)
RCSFILES=	Makefile $(SRCS)
ACCEPTFILES=	Makefile $(SRCS) $(PROGRAMS)
#
#
#
all:		 $(PROGRAMS)

inc_miner_version:
	vc -v --inc_miner_version -m o_dbm.rb $(SRCS) $(README)

inc_middle_version:
	vc -v --inc_middle_version -m o_dbm.rb $(SRCS) $(README)

inc_mager_version:
	vc -v --inc_mager_version -m o_dbm.rb $(SRCS) $(README)

Snapshot = Snapshot

PACKAGE_NAME:=$(TAR_PREFIX)-$(shell vc --version -m o_dbm.rb)

TGZ_FILES = $(foreach f,$(README) $(RB_SRCS),$(PACKAGE_NAME)/$(f))

tgz: $(Snapshot)/$(PACKAGE_NAME).tgz

$(Snapshot)/$(PACKAGE_NAME).tgz:
	if [ ! -e $(PACKAGE_NAME) ]; then \
	    ln -s . $(PACKAGE_NAME); \
	fi ;\
	echo "make $(PACKAGE_NAME) in $(Snapshot)"; \
	tar zcvf $(Snapshot)/$(PACKAGE_NAME).tgz $(TGZ_FILES)
	rm $(PACKAGE_NAME)

UPLOAD_LOCATION = ruby:public_html/src
upload: $(Snapshot)/$(PACKAGE_NAME).tgz
	scp -p $(Snapshot)/$(PACKAGE_NAME).tgz $(UPLOAD_LOCATION)


clean:;		

#
#	Definition for INSTALL
#
install:	$(foreach f, $(rb_p), $(RB_INSTDIR)/$(f)) \
		$(foreach f, $(pl_p), $(PL_INSTDIR)/$(f)) \
		$(foreach f, $(ppl_p), $(PL_INSTDIR)/$(f))
			
$(RB_INSTDIR)/%:	%
	@echo -n "installing $^  ..."
	@cp -p $^ $@
	@echo " done."

#	Definition for dependency of RUBY
#
#$(PROGRAMS): % : %.rb

test/% : test-%.rb
	@cp -p $^ $@
	@chmod +x $@

#
#
doc: doc/o_dbm.jp.html

doc/o_dbm.jp.html: doc/o_dbm.jp.rd
	env RUBYLIB= RUBYOPT= rd2 -rrd/rd2html-lib --html-title="o_dbm"  doc/o_dbm.jp.rd > doc/o_dbm.jp.html


#
#	Definition for dependency of PERL(%.ppl)
#
PERL	=	perl
PERLLIB =	-I/usr/local/lib/perl -I$(HOME)/var/lib/perl
ifdef ppl_p
$(ppl_p): %.pl : %.ppl
		@echo -n "Translating $< to $@ ..."
		@perl -ne '/^#!.*perl/ && do {\
			while (s/(-[^P 	]+)P/$$1/g || s/-P([^ 	]+)//g) {};\
			s/-P//g;\
			print $$_;\
		}; exit;' $<  > $@
		@/bin/sed -e '/^[^#]/b' \
			  -e '/^#[ 	]*include[ 	]/b' \
			  -e '/^#[ 	]*define[ 	]/b' \
			  -e '/^#[ 	]*if[ 	]/b' \
			  -e '/^#[ 	]*ifdef[ 	]/b' \
			  -e '/^#[ 	]*ifndef[ 	]/b' \
			  -e '/^#[ 	]*else/b' \
			  -e '/^#[ 	]*endif/b' \
			  -e 's/^#.*//' $<  | \
			/lib/cpp -C $(PERLLIB) >> $@
		@chmod +x $@
		@chmod +x $<
		@echo " done."
endif

#
#	Definition for printing
#
print:		$(foreach f,$(PRINTFILES),$(TS)/$(f).print)

$(foreach f,$(PRINTFILES),$(f).print): %.print: $(TS)/%.print
			
#$(TS)/%.print :	%
#		@$(PRINTER) $^
#		@touch $@

#
#	Definition for RCS
#
RCSFLAGS=   $(ROPTS) -l
RCS:		$(foreach f,$(RCSFILES),RCS/$(f),v)

$(RCS)/%,v ::	%
		-rcsdiff $^
		ci $(RCSFLAGS) $^

% :: %,v
% :: RCS/%,v
% :: SCCS/s.%
% :: s.%

rcsdiff:
		@echo "RCSDIFF"
		@echo "Files: "$(RCSFILES)
		@echo ""
		@rcsdiff $(RCSFILES)
		@echo ""
		@echo "RCSDIFF END"

#
#	Definition for depend
#
depend:
	-@cp /dev/null makedep						;\
	cp /dev/null makeprndep						;\
	if [ ! -d $(TS) ]						;\
		then mkdir $(TS)					;\
	fi								;\
	if [ ! -d RCS ]							;\
		then mkdir RCS						;\
	fi
ifdef c_p
	echo "#"					>> makedep	;\
	echo "#	$(PROGRAMS) dependency"			>> makedep	;\
	echo "#"					>> makedep	;\
	for f in $(PROGRAMS)						;\
	do								 \
		echo "$${f}:	\$$(objs_$${f}) \$$(LIBRARIES)"		 \
							>> makedep	;\
	done								;\
	echo "#"					>> makedep	;\
	echo "#	$(LIBRARIES) dependency"		>> makedep	;\
	echo "#"					>> makedep	;\
	for f in $(libraries)						;\
	do								 \
		echo "lib$${f}.a:	\$$(objs_$${f})">> makedep	;\
	done								;\
	echo "#"					>> makedep	;\
	echo "#	.o-file dependency"			>> makedep	;\
	echo "#"					>> makedep	;\
	gcc -MM $(HDRDIRS) $(ALL_SRCS)			>> makedep
endif
	echo -n "	Makefile remaking ..."				;\
	echo '/^#	Definition for Dependency Information /+2,$$d'> eddep;\
	echo '$$r makedep'					>> eddep;\
	echo 'w'						>> eddep;\
	cp Makefile .Makefile.bak					;\
	ed - Makefile < eddep						;\
	echo -n "."							;\
	rm -f eddep makedep makeRCSdep makeprndep			;\
	echo ''						>> Makefile	;\
	echo "#"					>> Makefile	;\
	echo '# DEPENDENCIES MUST END AT END OF FILE'	>> Makefile	;\
	echo '# IF YOU PUT STUFF HERE IT WILL GO AWAY'	>> Makefile	;\
	echo '# see make depend above'			>> Makefile ;\
	echo "#"					>> Makefile	;\
	echo " done.";
#
#	Definition for Dependency Information <No delete this line.>
#
