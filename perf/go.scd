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

~mungoClient = NetAddr(~mungo, 57121);
~mungoServer = NetAddr(~mungo, 57110);

~listenToMungo.free; ~listenToMungo = OSCFunc({ |msg| \flash.eval("mungo:" + msg[1].postln) }, '/mungo');

MIDIClient.init;
)



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

(
b = Buffer.readChannel(s, ~dir +/+ "samples/starbucks2.aiff", channels: #[0]);
c = Buffer.read(s, ~dir +/+ "samples/starbuckspv.aiff");

m = MixerChannel(\c1, s, 2, 2, outbus: ~master, completionFunc: { |chan|
	chan.newPostSend(~rvbchan, 0.4);
});
m => MCG(0);

n = MixerChannel(\c2, s, 2, 2, outbus: ~master, completionFunc: { |chan|
	chan.newPostSend(~rvbchan, 0.78);
});
n => MCG(1);
)



(
~rawbus = Bus.control(s, 7);
~lagbus = Bus.control(s, 7);
~lagger = Synth(\lags5, [inbus: ~rawbus, outbus: ~lagbus], target: s.asTarget, addAction: \addBefore);
~mouseToBus = {
	Out.kr([~rawbus.index + 5, ~lagbus.index + 5], [MouseX.kr(0, 1, 0, 0.1), MouseY.kr(0, 1, 0, 0.1)]);
}.play;

~limiter = Synth(\masterLimiter, nil, s.asTarget, \addAfter);

~rvbus = Bus.audio(s, 2);
~rvb.free;
~rvb = Synth(\reverb, [in: ~rvbus, out: 0], s.asTarget, \addAfter);

~srcbus = Bus.audio(s, 2);

~xfer = Synth(\rvbxfer, [inbus: ~srcbus, outbus: ~rvbus, level: 0.2], ~rvb, \addBefore);
)


~keys.free;
~keys = Synth(\keys, nil, s.asTarget, \addBefore);

(
a = nil;
~resp1.remove;
~resp1 = OSCresponderNode(s.addr, '/keystroke', { a.tryPerform(\set, \t_trig, 1) }).add;

a = n.play(\combs, [bufnum: b, attack: 15, release: 1.2, topaplevel: 0.25]);
)



(
~keyResp = PbindProxy(
	\instrument, \aps,
	\bufnum, b,
	\fwdback, Prand(#[-1, 1], inf),
	\speed, Pexprand(0.125, 8.0, inf),
	\rate, Pkey(\speed) * Pkey(\fwdback),
	\rawStart, Pwhite(0, (b.numFrames * 0.8).asInteger, inf),
	\start, Pif(Pkey(\rate) >= 0, Pkey(\rawStart), b.numFrames - Pkey(\rawStart)),
	\t_trig, 1,
	\dcyMul, Pwhite(0.2, 1.0, inf),
	\apdecay, Pexprand(0.2, 3.5, inf),
	\topaplevel, Pwhite(0.45, 1.0, inf),
	\totaldur, Pwhite(0.7, 5.0, inf),
	\release, Pwhite(0.1, 2.5, inf),
	\sustain, max(0.1, Pkey(\totaldur) - Pkey(\release)),
	\latency, 0.05,
	\group, m.synthgroup,
	\out, m.inbus
);

~keyRespStream = ~keyResp.asStream;

~resp2.remove;
~resp2 = OSCresponderNode(s.addr, '/keystroke', { ~keyRespStream.next(()).play }).add;
)

a.release(12); OSCpathResponder(s.addr, ['/n_end', a.nodeID], { ~resp1.remove; a = nil }).removeWhenDone.add;



~keyResp.set(\totaldur, Pwhite(0.2, 0.5, inf));
~keyResp.set(\release, 0.1);

~keyResp.set(\speed, 1);
~keyResp.set(\speed, Pwhite(0.3, 0.7, inf));
~keyResp.set(\speed, Pwhite(3.0, 7.0, inf));

~keyResp.set(\speed, Pexprand(0.8, 1.2, inf) * Env(#[0.3, 7, 1], #[20, 30], \exp));

~keyResp.set(\totaldur, Env(#[0.2, 1.0], #[15]).asStream);


~keyResp.set(\instrument, \combs);

~keyResp.set(\instrument, Pwrand(#[aps, combs], #[0.8, 0.2], inf));

// remove before performance
~keyResp.set(\totaldur, Pwhite(0.8, 1.7, inf));
~keyResp.set(\release, 0.7);




~resp2.remove;  // to stop responding to keystrokes



(
~repeaterNode = PbindProxy(
	\instrument, Pwrand(#[aps, combs], #[0.6, 0.4], inf),
	\drylev, 0,
	\bufnum, b,
	\fwdback, Prand(#[-1, 1], inf),
	\speed, Pexprand(1, 1.6, inf),
	\rate, Pkey(\speed) * Pkey(\fwdback),
	\rawStart, Pwhite(0, (b.numFrames * 0.8).asInteger, inf),
	\start, Pif(Pkey(\rate) >= 0, Pkey(\rawStart), b.numFrames - Pkey(\rawStart)),
	\t_trig, 1,
	\dcyMul, Pwhite(0.01, 0.06, inf),
	\apdecay, Pexprand(0.2, 3.5, inf),
	\topaplevel, Pwhite(0.05, 0.15, inf),
	\totaldur, Pwhite(3.0, 6.0, inf),
	\release, Pwhite(2.5, 5.0, inf),
	\sustain, max(0.1, Pkey(\totaldur) - Pkey(\release)),
	\latency, 0.04,
	\balance, Pwhite(-1.0, 1.0, inf),
	\amp, 0.3
);

~repeaterNodeStream = ~repeaterNode.asStream;

~nodeLimit = 30;
~nodes = IdentityDictionary.new;
~endWatcher.remove;
~endWatcher = OSCresponderNode(s.addr, '/n_end', e { |t, r, m|
	if(~nodes[m[1]].notNil) {
		~nodes[m[1]].stop;  // just in case...
		~nodes.removeAt(m[1]);
	};
}).add;

f = {
	var node, player;
	if(~nodes.size < ~nodeLimit) {
		node = ~repeaterNodeStream.next(()).play;
		thisThread.clock.sched(0, {
			player = Pfindur(node.totaldur - 0.12, Pbind(
				\type, \set,
				\id, node.id,
				\args, #[t_trig],
				\t_trig, 1,
				\delta, rrand(0.12, 0.26),
				\latency, 0.05,
				\group, n.synthgroup,
				\out, n.inbus
			)).play;
			~nodes[node.id[0]] = player;
		});
		node
	};
};
);


~resp3.remove;
~resp3 = OSCresponderNode(s.addr, '/keystroke', { f.value }).add;

~resp2.remove;


(~dir +/+ "perf/loadVideo.scd").loadPath;

(
BP(\wtop).free;
PR(\windowTop).chuck(BP(\wtop), nil, (guiProc: BP(\mg)));
BP(\wtop) =>.59 MT(1);

~transmit.remove;
~transmit = SimpleController(BP(\ml)).put(\allPtsReceived, e { |m|
	var toSend = [m.centroid.x, m.centroid.y,
		m.anglePoint.theta, m.anglePoint.rho, m.normmag];
	~mungoServer.tryPerform(\sendMsg, \c_setn, 0, 5, *toSend);
	s.sendMsg(\c_setn, ~rawbus.index, 5, *toSend);
});
)


// SECTION 2
~starbucksbus = Bus.audio(s, 1);

~bufplay = Synth(\normbufplay, [out: ~starbucksbus, bufnum: b], s.asTarget, \addBefore);

~randcomb = n.play(\randcomb, [inbus: ~starbucksbus, prob: 0.9]);

~resp3.remove;
~keys.free;


~map.listArgs
// ~map.(~randcomb, \y, \prob, -0.7, 0.7, 0.1, 0.9);
~map.(~randcomb, \mag, \prob, 0, 0.8, 0.9, 0.3, 6);
~map.(~randcomb, \x, \spread, -0.6, 0.6, -1, 1);

Fact(\lrtrig) => BP(\lrtrig);
BP(\lrtrig) => MT(1);

Fact(\lrtrig) => MT(1);


BP(\cm).free;
PR(\chordsAndModes) => BP(\cm);
0.25 => BP(\cm);
BP(\cm) => MT(1);




(
VC(\pl).free;
Fact(\plucky) => VC(\pl);
VC(\pl) => MCG(2);

VC(\pl2).free;
Fact(\plucky) => VC(\pl2);
VC(\pl2) => MCG(3);


BP(\st).free;
Fact(\repeaterBP).chuck(BP(\st), nil, (model: BP(\ml), chProc: BP(\cm)));
VC(\pl) => BP(\st);


BP(\arp).free;
Fact(\arpegBP).chuck(BP(\arp), nil, (model: BP(\ml), chProc: BP(\cm)));
VC(\pl2) => BP(\arp);
);

BP(\st) => MT(1);
BP(\arp) => MT(1);


~randcomb.release(15);



~master.levelTo(0, 35)