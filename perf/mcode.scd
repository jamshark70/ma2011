~jamesClient = NetAddr("127.0.0.1", 57120);  // change this IP address


~flash = { |text, time(4)|
	topEnvironment[\jamesClient].tryPerform(\sendMsg, '/mungo', text, time)
};

~flash.("xyz");

~flash.("国际电子音乐大师班系列");

(
~modeResp = OSCresponder(nil, '/newChord', { |t, r, msg|
	~root = msg[1];
	~chords = msg[2..].clump(5);
}).add;
)


s.boot;

~dir = d = ".....";  // fill with the real path to the main dir

b = Buffer.readChannel(s, d +/+ "samples/starbucks2.aiff", channels: #[0]);

(d +/+ "synthdefs.scd").load;

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


~keys = Synth(\keys, nil, s.asTarget, \addBefore);

(
a = nil;
~resp1.remove;
~resp1 = OSCresponderNode(s.addr, '/keystroke', { a.tryPerform(\set, \t_trig, 1) }).add;

a = Synth(\combs, [bufnum: b, attack: 15, release: 1.2, topaplevel: 0.25]);
)

// a.free; a = nil;


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
	\latency, 0.05
);

~keyRespStream = ~keyResp.asStream;

~resp2.remove;
~resp2 = OSCresponderNode(s.addr, '/keystroke', { ~keyRespStream.next(()).play }).add;
)

~keyResp.set(\totaldur, Pwhite(0.2, 0.5, inf));
~keyResp.set(\release, 0.1);

~keyResp.set(\speed, 1);

~keyResp.set(\instrument, \combs);

~keyResp.set(\instrument, Pwrand(#[aps, combs], #[0.8, 0.2], inf));


a.release(12); OSCpathResponder(s.addr, ['/n_end', a.nodeID], { ~resp1.remove; a = nil }).removeWhenDone.add;

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
	\amp, 1
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
				\latency, 0.05
			)).play;
			~nodes[node.id[0]] = player;
		});
		node
	};
};
)


~resp3.remove;
~resp3 = OSCresponderNode(s.addr, '/keystroke', { f.value }).add;

~resp2.remove;

~resp3.remove;



// SECTION 2
~starbucksbus = Bus.audio(s, 1);
~bufplay = Synth(\normbufplay, [out: ~starbucksbus, bufnum: b], s.asTarget, \addBefore);

c = Bus.control(s, 10);
c.setn(38.midicps * (1..10));

~fmg.free;
~fmg = Synth(\fmg, [thresh: 0.09, gfreqs: c.numChannels.collect { |i| ("c" ++ (c.index + i)).asSymbol }, envbuf: ~ebuf, sbus: ~starbucksbus, out: ~srcbus]);


~map.(a, \mag, \thresh, 0, 0.4, 0.14, 0.01, \lin);

~map.(a, \mx, \xfade, 0, 1, 0, 1);

~map.(a, \x, \xfade, -0.7, 0.7, 0, 1);

~map.(a, \y, \aEGsens, -0.6, 0.6, 0, 1);


a.release;



// SECTION 3

(
~mousexy2lang.free;
~mousexy2lang = {
	var coord = [MouseX.kr(0, 1, 0, 0.1), MouseY.kr(0, 1, 0, 0.1)];
	SendReply.kr(Impulse.kr(10), '/mousexy', coord);
}.play;

~mouseResp.remove;
~mouseResp = OSCresponder(s.addr, '/mousexy', { |t, r, msg|
	~mousex = msg[3];
	~mousey = msg[4];
}).add;
)

~intervalProbs = #[6, 5, 2, 1].normalizeSum;
~melodyRange = #[-4, 14];

~melody = PmonoArtic(\melody,
	#[degree, jumped], Prout({ |inval|
		var deg = rrand(1, 6), nextDeg, root, adjust, jumped;
		loop {
			root = topEnvironment[\root] ? 2;
			adjust = (root-2).keyToDegree(#[0, 2, 4, 5, 7, 9, 11], 12).trunc;
			nextDeg = deg + (
				#[1, 2, 3, 4].wchoose(~intervalProbs)
				* if(coin(~mousex)) { 1 } { -1 }
			);
			if(jumped = deg.inclusivelyBetween(*(~melodyRange)).not) {
				nextDeg = ~melodyRange[0].rrand(~melodyRange[1]);
			};
			inval = [(deg - adjust), jumped].yield;
			deg = nextDeg;
		}
	}),
	\root, Pfunc({ topEnvironment[\root] ? 2 }),
	\dur, Pwhite(1, 4, inf) * Pfunc({ ~mousey.linlin(0, 1, 0.2, 0.5) }),
	\legato, Pif(Pbinop('or', Pkey(\jumped), Pfunc({ 0.07.coin })), 0.9, 1.01),
	\mod_lev, 3,
	\car_detune, 1.006
).play;

~melody.stop;


~mousexy2lang.free; ~mouseResp.remove;
