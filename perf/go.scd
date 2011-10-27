// this is fiddly so I won't type it by hand

~mungo = "192.168.3.61";

~mungoClient = NetAddr(~mungo, 57120);
~mungoServer = NetAddr(~mungo, 57110);

\flash2.eval("you there?");

~receiver.free;
~receiver = OSCFunc({ |msg| \flash.eval(msg[1], msg[2]) }, '/mungo');






// this is even more fiddly!

(
var dir;

if(Func.exists(\ma2011dir)) {
	dir = \ma2011dir.eval;
	~dir = dir;
} {
	Error("Func(\\ma2011dir) doesn't exist. Check your startup configuration (instructions in addToYourStartupFile.scd).").throw;
};

(dir +/+ "perf/loadVideo.scd").loadPath;
)

();

(
BP.loadGui;

NotificationCenter.register(\chucklibGui, \ready, 'go.scd', e {
	(~dir +/+ "perf/defs.scd").loadPath;


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


	BP(\wtop).free;
	PR(\windowTop).chuck(BP(\wtop), nil, (guiProc: BP(\mg)));
	BP(\wtop) =>.72 MT(1);
});
)


