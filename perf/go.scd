(
var dir;

if(Func.exists(\ma2011dir)) {
	dir = \ma2011dir.eval;
} {
	Error("Func(\\ma2011dir) doesn't exist. Check your startup configuration (instructions in addToYourStartupFile.scd).").throw;
};

(dir +/+ "perf/loadVideo.scd").loadPath;
)

();

// s.boot;

// "~/share/SC/quarks/dewdrop_lib/ddwChucklib/Prototypes/devPreMIDIcfg.scd".loadPath;
// MIDIPort.init(~srcInports);

// \makeEmptyMixer8.eval;

BP.loadGui;



BP(\cm).free;
PR(\chordsAndModes) => BP(\cm);
0.25 => BP(\cm);


VC(\pl).free;
Fact(\plucky) => VC(\pl);
VC(\pl) => MCG(2);


BP(\st).free;
Fact(\repeaterBP).chuck(BP(\st), nil, (model: BP(\ml), chProc: BP(\cm)));
VC(\pl) => BP(\st);


BP(\arp).free;
Fact(\arpegBP).chuck(BP(\arp), nil, (model: BP(\ml), chProc: BP(\cm)));
VC(\pl) => BP(\arp);
