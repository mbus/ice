# make simv     <- compile simv if needed (but do not run)
# make syn_simv <- runs syn_int_simv interactively (much like make syn)
# make apr_simv <- runs syn_int_simv interactively (much like make syn)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# Execute Example: make simv VCSFLAGS="+define+TASK0"  <- This executes task0 testbenching

VCS = SW_VCS=2016.06 vcs +v2k +vc -sverilog +lint=all,noVCDE +warn=all -Mupdate -line -full64 -cm line+cond+fsm+tgl -debug_all
SYNVCS = SW_VCS=2016.06 vcs +v2k +vc -Mupdate -line -full64 +v2k +vc -sverilog +lint=all,noVCDE +warn=all -timescale=1ns/1ps +vcs+lic+wait +multisource_int_delays +plusarg_save +overlap -full64 -Mupdate -line -debug -cc gcc +libext+.v+.vlib+.vh +prof +neg_tchk +memopt -negdelay +define+SYN
APRVCS = SW_VCS=2016.06 vcs +v2k +vc -Mupdate -line -full64 +v2k +vc -sverilog +lint=all,noVCDE +warn=all -timescale=1ns/1ps +vcs+lic+wait +multisource_int_delays +plusarg_save +overlap -full64 -Mupdate -line -debug -cc gcc +libext+.v+.vlib+.vh +prof +neg_tchk +memopt -negdelay +define+APR
VCSFLAGS = 
INTFLAGS = -I +memcbk
VERILOG_PATH = ./../../
INCLUDE_DIR=$(VERILOG_PATH)/

##### 
# Modify starting here
#####

TESTBENCH = ackgen_test.v
SIMFILES = 	$(VERILOG_PATH)/ack_generator.v

#SYNFILES = 	$(MB_PATH)/../syn/mbus_node32_ab.nl.v \
#		$(MB_PATH)/../syn/mbus_node32_cd.nl.v \
#		$(MB_PATH)/../syn/mbus_node32_ef.nl.v \
#		$(MB_PATH)/../syn/mbus_ctrl_wrapper.nl.v
#APRFILES = 	$(MB_PATH)/../apr/mbus_node32_ab/mbus_node32_ab.apr.v \
#		$(MB_PATH)/../apr/mbus_node32_cd/mbus_node32_cd.apr.v \
#		$(MB_PATH)/../apr/mbus_node32_ef/mbus_node32_ef.apr.v \
#		$(MB_PATH)/../apr/mbus_ctrl_wrapper/mbus_ctrl_wrapper.apr.v

#####
# Do Not Modify
#####
simv:		$(SIMFILES) $(TESTBENCH)
		$(VCS) $(VCSFLAGS) $(TESTBENCH) $(SIMFILES) -o simv -cm line+cond+fsm+tgl +incdir+$(INCLUDE_DIR) -R | tee program.out

syn_simv:	$(SIMFILES) $(TESTBENCH)
		$(SYNVCS) $(VCSFLAGS) $(TESTBENCH) $(SYNFILES) -o syn_simv -cm line+cond+fsm+tgl +incdir+$(INCLUDE_DIR) -R | tee syn_program.out

apr_simv:	$(APRFILES) $(TESTBENCH)
		$(APRVCS) $(VCSFLAGS) $(TESTBENCH) $(APRFILES) -o apr_simv -cm line+cond+fsm+tgl +incdir+$(INCLUDE_DIR) -R | tee apr_program.out

# updated interactive debugger "DVE", using the latest version of VCS
dve:	$(SIMFILES) $(TESTBENCH) 
	$(VCS) $(VCSFLAGS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve +incdir+$(INCLUDE_DIR) -R -gui

.PHONY: simv syn_simv apr_simv dve

clean:	
	rm -rvf *simv *.daidir csrc vcs.key program.out \
	syn_simv syn_simv.daidir *program.out \
	int_simv int_simv.daidir syn_int_simv syn_int_simv.daidir \
	DVEfiles\
        dve *.vpd *.vcd *.dump ucli.key *.vdb REPORTS .saveDVEfiles .restart* .synopsys_dve* cm.log *.prof \
	INCA_libs waves.shm irun* nclaunch* ncverilog* result*.txt .nclaunch* .simvision log*

nuke:	clean
	rm -rvf *.vg *.rep *.db *.chk *.log *.out DVEfiles/
