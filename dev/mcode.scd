d = ".....";  // fill with the real path to the main dir
// d = thisProcess.nowExecutingPath.dirname.dirname;

s.options.memSize = 2**17;
s.boot;

(d +/+ "perf/synthdefs.scd").load;

~limiter = Synth(\masterLimiter, nil, s.asTarget, \addAfter);

b = Buffer.readChannel(s, d +/+ "samples/starbucks2.aiff", channels: #[0]);


BP.loadGui;

m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test1, s, 2, 2);
m => MCG(6); n => MCG(7);

PeakMonitor(n);

~keys = Synth(\keys, nil, s.asTarget, \addBefore);

a = nil;
~resp1.remove;
~resp1 = OSCresponderNode(s.addr, '/keystroke', { a.tryPerform(\set, \t_trig, 1) }).add;

a = Synth(\combs, [bufnum: b, attack: 15, release: 1.2, topaplevel: 0.25]);
a.free; a = nil;

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

~keyResp.set(\totaldur, Pwhite(0.2, 0.5, inf));
~keyResp.set(\release, 0.1);

~keyResp.set(\speed, 1);

~keyResp.set(\instrument, \combs);

~keyResp.set(\instrument, Pwrand(#[aps, combs], #[0.8, 0.2], inf));


a.release(12); OSCpathResponder(s.addr, ['/n_end', a.nodeID], { ~resp1.remove; a = nil }).removeWhenDone.add;

~resp2.remove;  // to stop responding to keystrokes



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

e = f.();


~resp3.remove;
~resp3 = OSCresponderNode(s.addr, '/keystroke', { f.value }).add;



n = 5;
a = m.play {
	var sig = PlayBuf.ar(1, b, loop: 1),
	freq = MouseY.kr(200, 1000, 1, 0.1);
	DynKlank.ar(`[
		freq * Array.fill(n, { |i| ((i+1) * ((1+sqrt(5)) / 2)) + LFNoise1.kr(Rand(1.6, 6.4)).exprange(0.95, 0.95.reciprocal) }),
		0.1 ! n,
		2.2 ! n
	], sig);
};

a.free;

a.trace;


g = GenericGlobalControl(\thresh, nil, 0.8, [0, 1]);
g => VP(0);

g.spec = [1e-6, 0.1];

~ebuf = Buffer.sendCollection(s, Env.perc(0.01, 0.99).asSignal(512));

n = 10;
a = m.play({ |afreq = 400, pfreq = 200, thresh = 0.8, rate = 1, minTrigTime = 0.1|
	var sig = Normalizer.ar(PlayBuf.ar(1, b, rate: rate, loop: 1)),
	analysis = BPF.ar(
		sig,
		afreq * rate * Array.fill(n, { |i| ((i+1) * ((1+sqrt(5)) / 2)) + LFNoise1.kr(Rand(1.6, 6.4)).exprange(0.95, 0.95.reciprocal) }),
		0.03  // Q ~= 33
	),
	trigs = A2K.kr(Trig1.ar(analysis > (thresh / (1..n)), minTrigTime)),
	onetrig = trigs.sum,
	gfreqs = pfreq * (1..n);
	GrainFM.ar(2, trigs, dur: 0.12,
		carfreq: gfreqs, modfreq: gfreqs * (TIRand.kr(1, 5, onetrig) + TRand.kr(-0.05, 0.05, onetrig)),
		index: TRand.kr(0.3, 1.2, onetrig),
		pan: TRand.kr(-1.0, 1.0, trigs),
		// pan: (-1.0, (n-1).reciprocal*2 - 1 .. 1.0),
		envbufnum: ~ebuf, maxGrains: 512
	).sum
}, [thresh: g, pfreq: 38.midicps, rate: 0.3]);

a.free;

a.trace



SynthDef(\fmg, { |afreq = 400, thresh = 0.8, rate = 1, minTrigTime = 0.1, gate = 1, out|
	var n = 10,
	sig = Normalizer.ar(PlayBuf.ar(1, b, rate: rate, loop: 1)),
	analysis = BPF.ar(
		sig,
		afreq * rate * Array.fill(n, { |i| ((i+1) * ((1+sqrt(5)) / 2)) + LFNoise1.kr(Rand(1.6, 6.4)).exprange(0.95, 0.95.reciprocal) }),
		0.03  // Q ~= 33
	),
	trigs = A2K.kr(Trig1.ar(analysis > (thresh / (1..n)), minTrigTime)),
	onetrig = trigs.sum,
	gfreqs = NamedControl.kr(\gfreqs, 200 * (1..n)),
	eg = EnvGen.kr(Env.asr(3, 1, 6, #[4, -4]), gate, doneAction: 2);
	Out.ar(out,
		GrainFM.ar(2, trigs, dur: 0.12,
			carfreq: gfreqs, modfreq: gfreqs * (TIRand.kr(1, 5, onetrig) + TRand.kr(-0.05, 0.05, onetrig)),
			index: TRand.kr(0.3, 1.2, onetrig),
			pan: TRand.kr(-1.0, 1.0, trigs),
			envbufnum: ~ebuf ?? { -1 }, maxGrains: 512
		).sum * eg
	)
}).add;

c = Bus.control(s, 10);
c.setn(38.midicps * (1..10));

n = MCG(7).v.mixer;

a = n.play(\fmg, [thresh: g, gfreqs: c.numChannels.collect { |i| ("c" ++ (c.index + i)).asSymbol }]);

a.trace;

a.free;

// needs reverb!!!
// map parameters on, especially to make this very quiet, unobtrusive

(instrument: \ctlPoint, outbus: c.index + (0..9), time: 12, curve: \exp, value: (Pseries(-7, Pwhite(1, 4, inf), 10).asStream.all.degreeToKey(#[0, 2, 4, 5, 7, 9, 11], 12) + 62).midicps).play;
