~dir = ".....";  // fill with the real path to the main dir
// ~dir = thisProcess.nowExecutingPath.dirname.dirname;

s.options.memSize = 2**17;
s.boot;

(~dir +/+ "perf/synthdefs.scd").load;

~limiter = Synth(\masterLimiter, nil, s.asTarget, \addAfter);

b = Buffer.readChannel(s, ~dir +/+ "samples/starbucks2.aiff", channels: #[0]);


BP.loadGui;

m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
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



// simple buffer player
SynthDef(\normbufplay, { |bufnum, out, rate = 1, start = 0|
	Out.ar(out, Normalizer.ar(PlayBuf.ar(1, bufnum, rate: rate, startPos: start, loop: 1)))
}).add;

~starbucksbus = Bus.audio(s, 1);

~bufplay = Synth(\normbufplay, [out: ~starbucksbus, bufnum: b], s.asTarget, \addBefore);

a = m.play({ |thresh = 0.09, minTrigTime = 0.05|
	var afreq = 400, rate = 1, n = 10,
	analysis = BPF.ar(
		In.ar(~starbucksbus, 1),
		afreq * rate * Array.fill(n, { |i| ((i+1) * ((1+sqrt(5)) / 2)) + LFNoise1.kr(Rand(1.6, 6.4)).exprange(0.95, 0.95.reciprocal) }),
		0.01  // Q ~= 100
	),
	trigs = A2K.kr(Trig1.ar(analysis > (thresh / (1..n)), minTrigTime)),
	// onetrig = trigs.sum,
	gfreqs = NamedControl.kr(\gfreqs, 200 * (1..n)),

}, []);

a.free;

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



SynthDef(\fmg, { |afreq = 400, thresh = 0.8, rate = 1, minTrigTime = 0.1, gate = 1, out,
	graindur = 0.12, maxratio = 5, maxrand = 0.05, modindexlo = 0.3, modindexhi = 1.2,
	gAmp = 0.2,
	panwidth = 1, pancenter = 0, envbuf = -1, sbus,
	apdecay = 0.1, aEGstretch = 1, aEGsens = 1, xfade = 0|
	var n = 10,
	sig = In.ar(sbus, 1),
	analysis = BPF.ar(
		sig,
		afreq * rate * Array.fill(n, { |i| ((i+1) * ((1+sqrt(5)) / 2)) + LFNoise1.kr(Rand(1.6, 6.4)).exprange(0.95, 0.95.reciprocal) }),
		0.03  // Q ~= 33
	),
	trigs = A2K.kr(Trig1.ar(analysis > (thresh / (1..n)), minTrigTime * Array.fill(n, { Rand(0.9, 0.111) }))),
	onetrig = trigs.sum,
	gfreqs = NamedControl.kr(\gfreqs, 200 * (1..n)),
	eg = EnvGen.kr(Env.asr(3, 1, 6, #[4, -4]), gate, doneAction: 2),
	grains = GrainFM.ar(2, trigs, dur: graindur,
		carfreq: gfreqs,
		modfreq: gfreqs *
		(TIRand.kr(1, maxratio, onetrig) + TRand.kr(maxrand.neg, maxrand, onetrig)),
		index: TRand.kr(modindexlo, modindexhi, onetrig),
		pan: TRand.kr((pancenter - panwidth).clip(-1, 1),
			(pancenter + panwidth).clip(-1, 1), trigs),
		envbufnum: envbuf
	).sum,
	analysisEGs = (EnvGen.kr(Env.perc(0.01, graindur * aEGstretch), trigs) - 1) * aEGsens + 1;
	analysis = Pan2.ar(analysis, (-1.0, 2/(n-1) - 1 .. 1.0).scramble, analysisEGs).sum;
	analysis = analysis + AllpassL.ar(analysis, 0.05,
		LFDNoise1.kr(LFNoise1.kr(0.5).range(0.3, 4), 0.02, 0.03),
		apdecay
	);
	Out.ar(out,
		XFade2.ar(analysis, grains * gAmp, xfade * 2 - 1, eg)
	)
}).add;


c = Bus.control(s, 10);
c.setn(38.midicps * (1..10));

n = MCG(7).v.mixer;

a = n.play(\fmg, [thresh: 0.09, gfreqs: c.numChannels.collect { |i| ("c" ++ (c.index + i)).asSymbol }, envbuf: ~ebuf, sbus: ~starbucksbus, out: ~srcbus]);

a.free;
a = Synth(\fmg, [thresh: 0.09, gfreqs: c.numChannels.collect { |i| ("c" ++ (c.index + i)).asSymbol }, envbuf: ~ebuf, sbus: ~starbucksbus, out: ~srcbus]);

a.trace;

a.release;

z = ~map.(a, \mag, \thresh, 0, 0.4, 0.14, 0.01, \lin);
~map.(a, \mx, \xfade, 0, 1, 0, 1);
~map.(a, \x, \xfade, -0.7, 0.7, 0, 1);
~map.(a, \y, \aEGsens, -0.6, 0.6, 0, 1);

a.trace;

// map parameters on, especially to make this very quiet, unobtrusive

(instrument: \ctlPoint, outbus: c.index + (0..9), time: 3, curve: 0, value: (Pseries(-7, Pwhite(1, 4, inf), 10).asStream.all.degreeToKey(#[0, 2, 4, 5, 7, 9, 11], 12) + 62).midicps).play;





// synth, name, ctlName, inMin, inMax, outMin, outMax
z = ~map.(a, \mag, \thresh, 0, 0.4, 0.14, 0.01, \lin);

~unmap.(a, \mag);

a.release;




// melody

SynthDef(\melody, { |freq = 440, gate = 1, mod_ratio = 2, mod_lev = 1, car_detune = 1.003, car_amp = 0.1, out, pan, freqlag = 0.15|
	var ampenv = EnvGen.kr(Env.adsr(0.1, 0.4, 0.5, 0.15), gate, doneAction: 2),
	modenv = EnvGen.kr(Env.adsr(0.08, 0.07, 0.5, 0.25)),
	lfreq = Lag.kr(freq, freqlag),
	sig = [1, car_detune].collect({ |fmul|
		var f = lfreq * fmul,
		mod = SinOsc.ar(f * mod_ratio, 0) * mod_lev * modenv;
		SinOsc.ar(f + (f * mod), 0)
	}).sum;
	Out.ar(out, Pan2.ar(sig, pan, car_amp * ampenv));
}).add;

(instrument: \melody, mod_lev: 3, sustain: 2, car_detune: 1.006).play;

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

s.sendMsg(\n_free, 1005);

BP(\cm).play;
BP(\cm).stop;

Pbinop('or', Pfunc({ 0.07.coin }), false).asStream.nextN(20);