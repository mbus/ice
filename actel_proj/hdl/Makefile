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
#ANDREW: decided to just include the files locally
#MB_PATH = ../../../mbus/mbus/verilog/no_pwr_gating_yesheng
MB_PATH = .

##### 
# Modify starting here
#####

#TESTBENCH = tb_mbus.v
TESTBENCH = testbench.v
SIMFILES = 	$(MB_PATH)/mbus_addr_rf.v \
		$(MB_PATH)/mbus_ice_driver_tx.v \
		$(MB_PATH)/mbus_ice_driver_rx.v \
		$(MB_PATH)/mbus_swapper.v \
		$(MB_PATH)/mbus_wire_ctrl.v \
		$(MB_PATH)/mbus_ctrl.v \
		$(MB_PATH)/mbus_node_master_en.v \
		$(MB_PATH)/mbus_general_layer_wrapper.v \
		ack_generator.v \
		basics_int.v \
		gpio_int.v \
		bus_interface.v \
		debounce_ms.v \
		double_latch.v  \
		ein_int.v \
		ein_mod.v \
		global_event_counter.v \
		goc_int.v \
		header_decoder.v \
		ice_bus.v \
		ice_bus_controller.v \
		mbus_layer_wrapper_ice.v \
		message_fifo.v \
		pmu_i2c.v \
		pmu_int.v \
		por.v \
		priority_select.v \
		pwm_mod.v \
		ram.v \
		sync.v \
		toplevel.v \
		uart.v 

SYNFILES = 	$(MB_PATH)/../syn/mbus_node32_ab.nl.v \
		$(MB_PATH)/../syn/mbus_node32_cd.nl.v \
		$(MB_PATH)/../syn/mbus_node32_ef.nl.v \
		$(MB_PATH)/../syn/mbus_ctrl_wrapper.nl.v
APRFILES = 	$(MB_PATH)/../apr/mbus_node32_ab/mbus_node32_ab.apr.v \
		$(MB_PATH)/../apr/mbus_node32_cd/mbus_node32_cd.apr.v \
		$(MB_PATH)/../apr/mbus_node32_ef/mbus_node32_ef.apr.v \
		$(MB_PATH)/../apr/mbus_ctrl_wrapper/mbus_ctrl_wrapper.apr.v

#####
# Do Not Modify
#####
simv:		$(SIMFILES) $(TESTBENCH)
		$(VCS) $(VCSFLAGS) $(TESTBENCH) $(SIMFILES) -o simv -cm line+cond+fsm+tgl +incdir+$(MB_PATH) -R | tee program.out
		#urg -dir simv.vdb -report ./REPORTS

syn_simv:	$(SIMFILES) $(TESTBENCH)
		$(SYNVCS) $(VCSFLAGS) $(TESTBENCH) $(SYNFILES) -o syn_simv -cm line+cond+fsm+tgl +incdir+$(MB_PATH) -R | tee syn_program.out
		#urg -dir syn_simv.vdb -report ./REPORTS

apr_simv:	$(APRFILES) $(TESTBENCH)
		$(APRVCS) $(VCSFLAGS) $(TESTBENCH) $(APRFILES) -o apr_simv -cm line+cond+fsm+tgl +incdir+$(MB_PATH) -R | tee apr_program.out
		#urg -dir apr_simv.vdb -report ./REPORTS

# updated interactive debugger "DVE", using the latest version of VCS
dve:	$(SIMFILES) $(TESTBENCH) 
	$(VCS) $(VCSFLAGS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve +incdir+$(MB_PATH) -R -gui

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
