// this is fiddly so I won't type it by hand
(
if(Func.exists(\ma2011dir)) {
	~dir = \ma2011dir.eval;
} {
	Error("Func(\\ma2011dir) doesn't exist. Check your startup configuration (instructions in addToYourStartupFile.scd).").throw;
};

loadPath(~dir +/+ "perf/defs.scd");

s.options.memSize = 2**17;

~mungo = "192.168.1.101";

~mungoClient = NetAddr(~mungo, 57120);
~mungoServer = NetAddr(~mungo, 57110);

MIDIClient.init;
)

~receiver.free;
~receiver = OSCFunc({ |msg| msg.postcs; \flash.eval(msg[1], msg[2]) }, '/mungo');

\flash2.eval("you there?");

\flash.eval("you don't need Max/M$$$$P".escapeChar($$));
\flash.eval("you don't need Mac O$$$$X".escapeChar($$));

\mungo.eval("hello");

f = { |time, replyAddr, recvPort, msg| msg.postcs };
thisProcess.recvOSCfunc = thisProcess.recvOSCfunc.addFunc(f);

thisProcess.recvOSCfunc = thisProcess.recvOSCfunc.removeFunc(f);

NetAddr.localAddr.sendMsg("/test");

(
var mtw, mxw, vpw;
s.boot;

MT(1).gui;
mtw = Window.allWindows.last;
mtw.bounds = mtw.bounds.right_(Window.screenBounds.right).bottom_(Window.screenBounds.bottom);

\makeEmptyMixer8.eval;
mxw = MixingBoard.at(0).w;
defer({ mxw.bounds = mxw.bounds.right_(Window.screenBounds.right).top_(0) }, 0.5);

VoicerProxy.new => VP.prNew(0);
5.do { VP(0).v.addControlProxy(VoicerGCProxy.new, true) };
VP(0).v.gui;
vpw = Window.allWindows.last;
vpw.bounds = vpw.bounds
	.right_(Window.screenBounds.right-12)
	.bottom_(Window.screenBounds.bottom);
mtw.alwaysOnTop_(true);
)

// BP.loadGui;

(~dir +/+ "perf/server-defs.scd").loadPath;
(~dir +/+ "perf/synthdefs.scd").loadPath;

b = Buffer.readChannel(s, ~dir +/+ "samples/starbucks2.aiff", channels: #[0]);
c = Buffer.read(s, ~dir +/+ "samples/starbuckspv.aiff");







(~dir +/+ "perf/loadVideo.scd").loadPath;

(
BP(\wtop).free;
PR(\windowTop).chuck(BP(\wtop), nil, (guiProc: BP(\mg)));
BP(\wtop) =>.72 MT(1);
)



(
~rawbus = Bus.control(s, 7);
~lagbus = Bus.control(s, 7);
~lagger = Synth(\lags5, [inbus: ~rawbus, outbus: ~lagbus], target: s.asTarget, addAction: \addBefore);
~mouseToBus = {
	Out.kr([~rawbus.index + 5, ~lagbus.index + 5], [MouseX.kr(0, 1, 0, 0.1), MouseY.kr(0, 1, 0, 0.1)]);
}.play;

~transmit.remove;
~transmit = SimpleController(BP(\ml)).put(\allPtsReceived, e { |m|
	var toSend = [m.centroid.x, m.centroid.y,
		m.anglePoint.theta, m.anglePoint.rho, m.normmag];
	~mungoServer.tryPerform(\sendMsg, \c_setn, 0, 5, *toSend);
	s.sendMsg(\c_setn, ~rawbus.index, 5, *toSend);
});
)



(
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
)