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

m = MixerChannel(\demo, s, 2, 2);
m => MCG(0);


// a variant: shorter notes
// flurries of faster notes --> pulse

(
WrapInstr("osc2.fm2car_v", { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_detune,
	car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale;
	var sig, mod, car_amp, mod_amp;
	// so this here is an ass-ugly workaround for the fact that VOsc chokes on FM
	var blendOsc = { |buf1, buf2, args, frac = 0.5|
		var	osc1 = Osc.ar(buf1, *args),
		osc2 = Osc.ar(buf2, *args);
		// linear or equal-power... ehhhh... equal-power it is
		XFade2.ar(osc1, osc2, frac.madd(2, -1))
		// (osc2 - osc1) * frac + osc1
	};
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
	* EnvGen.kr(mod_env, gate);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];
	sig = Mix(blendOsc.(car_buf, car_buf + 1, freq + (mod * freq), 0))
		* car_amp * EnvGen.kr(car_env, gate, doneAction:2)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp]]);

WrapInstr("osc2.fm2carpan", { |pan = 0, gate = 1, mod_env, mod_vs = 0|
	mod_env = mod_env.dereference.value(gate, mod_vs);
	Pan2.ar(
		WrapInstr.wrap("osc2.fm2car_v", [
			nil, gate, nil, mod_env, nil, nil, nil, nil, nil, nil, nil,
			mod_vs
		]),
		pan
	)
}, [\bipolar, #[0, 1], EnvSpec(Env.one), #[0, 1]]);
)

~cb = Buffer.alloc(s, 2048, 1);
~mb = Buffer.alloc(s, 2048, 1);

~cb.sine1(#[1, 0.7, 0.4]);
~cb.sine1(#[1, 0, 0.6]);
~mb.sine1(#[1]);

WrapInstr("osc2.fm2carpan").listArgs

v = WrapInstr("osc2.fm2carpan").miditest(0, [
	car_buf: ~cb, mod_buf: ~mb,
	car_env: Env(#[0, 1, 0.4, 0, 0], #[0.01, 0.15, 2.5, 0.08], -4, releaseNode: 3),
	mod_env: `{ |gate, mod_vs|
		Env([1, gate.madd(mod_vs, 1), 1], [0.01, gate.madd(0.8, 0.4)], -4)
	},
	detune: -0.2755905511811,
	car_detune: 1.0036415723414,
	mod_vs: 0.66141732283465,
	mod_lev: 4.0617792969413,
	mod_ratio: 1,
	car_vs: 0.63779527559055,
	keyscale: 0.22882313497919
], target: m);


(
make: { |name|
	var out;
	~cb = Buffer.allocConsecutive(8, s, 2048, 1);
	~mb = Buffer.alloc(s, 2048, 1);

	// ~cb.sine1(#[1, 0, 0.6]);
	fork {
		var cond = Condition.new;
		~cb.do { |buf, i|
			// Department of Redundancy Department:
			// if I block this thread by cond.hang, it also blocks sendCollection
			// grrrrrrr...
			fork {
				buf.sendCollection(
					Signal.fill(buf.numFrames div: 2, { (i / ~cb.size).rand2 }).asWavetable,
					action: { cond.unhang });
			};
			cond.hang;  // ensure signal is sent before adding sine content
			buf.sine1(#[1, 0, 0.6] * (1 - (i / ~cb.size)).debug("sinemul"), clearFirst: false);
			s.sync;
		};
		~collIndex.debug("buffers ready");
	};
	~mb.sine1(#[1]);

	~target = MixerChannel(name, s, 2, 2, level: -14.dbamp /*, completionFunc: {} */);

	out = Voicer(25, WrapInstr("osc2.fm2carpan"), [
		car_buf: ~cb.first.bufnum,  // allow modulation
		mod_buf: ~mb,
		car_env: Env(#[0, 1, 0.4, 0, 0], #[0.01, 0.15, 2.5, 0.08], -4, releaseNode: 3),
		mod_env: `{ |gate, mod_vs|
			Env([1, gate.madd(mod_vs, 1), 1], [0.01, gate.madd(0.8, 0.4)], -4)
		},
		detune: -0.2755905511811,
		car_detune: 1.0076415723414,
		mod_vs: 0.66141732283465,
		mod_lev: 4.0617792969413,
		mod_ratio: 1,
		car_vs: 0.63779527559055,
		keyscale: 0.22882313497919
	], target: ~target);

	out
},
free: { [~target, ~cb, ~mb].free },
type: \voicer) => Fact(\plucky);

VC(\pl).free;
Fact(\plucky) => VC(\pl);
VC(\pl) => MCG(2);

k = VoicerMIDISocket(0, VC(\pl).v);

g = GenericGlobalControl(\sync, nil, 0);
g => VP(0);

p = Pbind(
	\type, \voicerNote,
	\voicer, VC(\pl).v,
	\degree, Pxrand((-7 .. 7), inf),
	\root, 2,
	\dur, Pexprand(0.065, 0.2, inf).collect { |dur|
		var	rounded = min(0.125, dur.round(0.125)) - (thisThread.beats % 0.125);
		if(rounded < 0.125) { rounded = rounded + 0.125 };
		dur.blend(rounded, g.value)
	},
	\sustain, 0.2,
	\gate, 0.02
);

q = Ppar(
	Array.fill(4, { |i|
		Pbind(
			\pan, i / 1.5 - 1,
			\degree, Pkey(\degree) + ((i - 1) * 7)
		) <> p
	})
).play;

q.stop;

~rvbchan = MixerChannel(\rvb, s, 2, 2, level: 2.sqrt, completionFunc: { |chan|
	~rvb = chan.playfx(Instr("busfx.freeverb2"), [0, 1.0, 0.69659996032715, 0.078699998557568, 1.0]);
	//	defer { ~rvb.gui };
});
~rvbchan => MCG(6);

~hpchan = MixerChannel(\hp, s, 2, 2, level: 2.sqrt, outbus: ~rvbchan, completionFunc: { |chan|
	~hp = chan.playfx(
		Instr("busfx.hpf", { |bus, numChan = 1, freq|
			HPF.ar(In.ar(bus, numChan), freq)
		}, [\audiobus, StaticSpec(1, 8, \lin, 1), \freq]),
		[0, 2, 300]
	);
	// defer { ~hp.gui };
});
~hpchan => MCG(5);

VC(\pl).env.target.newPostSend(~hpchan, 0.86);

VC(\pl).env.target.postSends.do(_.free)

MixingBoard.at(0).refresh;

Library.at(Instr, \busfx).keys
Spec.specs.keys.select { |key| key.asString.containsi("") };

PeakMonitor(~rvbchan)

~hp.synth.trace
~rvb.synth.trace

~hpchan.level = 2.sqrt;
~hpchan.synth.trace

~rvbchan.level = 2.sqrt;


SynthDef("rvbxfer", {
	arg inbus, outbus, level = 0.1;
	var sig = In.ar(inbus, 2);
	Out.ar(outbus, sig * level);
	Out.ar(0, sig);
}).send(s);

SynthDef(\reverb, { |in, out, earlyDecay = 0.08, decay = 2, earlyAmp = 0.2, tailAmp = 1|
	var sig = In.ar(in, 2),
	early = LeakDC.ar(
		sig.collect { |chan|
			CombL.ar(chan, 0.03, Array.fill(3, { Rand(0.01, 0.03) }), earlyDecay).sum
		}
	),
	tail = sig;
	4.do {
		tail = tail + AllpassL.ar(tail, 0.08, Rand(0.03, 0.08), decay);
	};
	Out.ar(out, (early * earlyAmp) + (tail * tailAmp));
}).add;

~rvbus = Bus.audio(s, 2);

~rvb.free;
~rvb = Synth(\reverb, [in: ~rvbus, out: 0], s.asTarget, \addAfter);

a = {
	var trig = Impulse.kr(8), eg = Decay2.kr(trig, 0.01, 0.09);
	Pan2.ar(SinOsc.ar(TExpRand.kr(200, 800, trig), 0, 0.7 * eg), SinOsc.kr(0.1))
}.play(outbus: ~rvbus);

a.free;

~rvb.trace

~srcbus = Bus.audio(s, 2);

~xfer = Synth(\rvbxfer, [inbus: ~srcbus, outbus: ~rvbus, level: 1], ~rvb, \addBefore);

~xfer.set(\level, 0.2);

~xfer.trace

PeakMonitor(~rvbus)



// randcomb
b = Buffer.readChannel(s, ~dir +/+ "samples/starbucks2.aiff", channels: #[0]);

SynthDef(\normbufplay, { |bufnum, out, rate = 1, start = 0|
	Out.ar(out, Normalizer.ar(PlayBuf.ar(1, bufnum, rate: rate, startPos: start, loop: 1)))
}).add;

~starbucksbus = Bus.audio(s, 1);

~bufplay = Synth(\normbufplay, [out: ~starbucksbus, bufnum: b], s.asTarget, \addBefore);

SynthDef(\randcomb, { |inbus, prob = 0.5, t_trig = 1, gate = 1, xftime = 0.5, spread = 0, out|
	var sig = In.ar(inbus, 1),
	fft = FFT(LocalBuf(1024, 1), sig),
	fftR,
	fft2 = PV_Copy(fft, LocalBuf(1024, 1)),
	fft2R,
	panTarget = ToggleFF.kr(t_trig),
	fbTime = Latch.kr(xftime, t_trig),
	tgate = Trig1.kr(t_trig, fbTime),
	prevtrig = Delay1.kr(t_trig),
	gap = (t_trig >= 1) * (prevtrig <= 0) * (tgate >= 1),
	pan = EnvGen.ar(Env(panTarget ! 3, [fbTime, ControlDur.ir], releaseNode: 1), tgate - gap),
	eg = EnvGen.kr(Env.asr(2, 1, 3), gate, doneAction: 2),
	sig1, sig2;
	fft = PV_RandComb(fft <! fft2, prob, t_trig * (panTarget <= 0));
	fftR = PV_Copy(fft, LocalBuf(1024, 1));
	fftR = PV_RandComb(fftR, 0.5);
	fft = PV_MagSubtract(fft, fftR);
	fft2 = PV_RandComb(fft2, prob, t_trig * (panTarget >= 1));
	fft2R = PV_Copy(fft2, LocalBuf(1024, 1));
	fft2R = PV_RandComb(fft2R, 0.5);
	fft2 = PV_MagSubtract(fft2, fft2R);
	sig1 = Pan2.ar(IFFT([fft, fftR]), spread * #[-1, 1]);
	sig2 = Pan2.ar(IFFT([fft2, fft2R]), spread * #[-1, 1]);
	Out.ar(out, XFade2.ar(sig1, sig2, pan.madd(2, -1), eg).sum)
}).add;

XFade2.kr([1, 2], [3, 4], 0).insp

~randcomb = n.play(\randcomb, [inbus: ~starbucksbus, prob: 0.9]);

~map.listArgs
// ~map.(~randcomb, \y, \prob, -0.7, 0.7, 0.1, 0.9);
~map.(~randcomb, \mag, \prob, 0, 0.8, 0.9, 0.1);
~map.(~randcomb, \x, \spread, -0.6, 0.6, -1, 1);

Fact.keys
Fact(\lrtrig) => BP(\lrtrig);
BP(\lrtrig) => MT(1);

~unmap.(~randcomb, \theta);

~rcmc = MixerChannel(\rcomb, s, 2, 2, outbus: ~master);
~randcomb.moveToHead(~rcmc.synthgroup);
~randcomb.set(\out, ~rcmc.inbus);
~rcmc => MCG(0);


~randcomb.release;

~randcomb.set(\t_trig, 1);

~randcomb.trace;

a.free;

a = ~master.play { In.ar(~starbucksbus, 1) ! 2 };
a.free;


c.free;
c = Buffer.alloc(s, 20.calcPVRecSize(1024, 0.25, 44100));
c.write(~dir +/+ "samples/starbuckspv.aiff", sampleFormat: "float");

{
	var fft = FFT(LocalBuf(1024, 1), In.ar(~starbucksbus, 1), 0.25, 1);
	PV_RecordBuf(fft, c, run: 1, hop: 0.25);
	FreeSelf.kr(Trig1.kr(Impulse.kr(0), 20.0) <= 0);
	0
}.play;

a = ~master.play {
	var fft = PV_PlayBuf(LocalBuf(1024, 1), c, 0.1, loop: 0);
	(IFFT(fft) * EnvGen.kr(Env.linen(0.01, 1.98, 0.01), doneAction: 2)) ! 2
};


f = (c.numFrames - 3) / 1024;
x = 4.1;
a = ~master.play {
	var	pos = EnvGen.kr(Env([0, 1 - (x/f), 1 - (x/f)], #[3, 2], -6), doneAction: 2),
	fft = PV_BufRd(LocalBuf(1024), c, pos);
	IFFT(fft) ! 2
};



a.trace;

c.getn(0, 50, _.postln);


SynthDef(\pv, { |out, pvbuf, amp = 0.1, time = 0.5, panMul = -1, panAdd = 0, scrambleWidth = 0.2|
	var point = EnvGen.kr(NamedControl.kr(\ptenv, (0 ! 20).overWrite(Env(#[0, 1], [1]).asArray)), timeScale: time),
	stretch = EnvGen.kr(NamedControl.kr(\stretchenv, (0 ! 20).overWrite(Env.one.asArray)), timeScale: time),
	shift = EnvGen.kr(NamedControl.kr(\shiftenv, (0 ! 20).overWrite(Env.zero.asArray)), timeScale: time),
	scramble = EnvGen.kr(NamedControl.kr(\scramble, (0 ! 20).overWrite(Env.zero.asArray)), timeScale: time),
	pan1 = EnvGen.kr(NamedControl.kr(\pan1env, (0 ! 20).overWrite(Env.zero.asArray)), timeScale: time),
	pan2 = (pan1 * panMul + panAdd).fold(-1, 1),
	eg = EnvGen.kr(NamedControl.kr(\env, (0 ! 20).overWrite(Env.perc(0.01, 0.99).asArray)), timeScale: time, doneAction: 2),
	fft, fft2;
	fft = PV_BufRd(LocalBuf(1024, 1), pvbuf, point);
	fft = PV_BinScramble(fft, scramble, scrambleWidth);
	fft = PV_BinShift(fft, stretch, shift);
	fft2 = PV_Copy(fft, LocalBuf(1024, 1));
	fft = IFFT(PV_OddBin(fft <! fft2));
	fft2 = IFFT(PV_EvenBin(fft2));
	Out.ar(out, Pan2.ar([fft, fft2], [pan1, pan2], eg * amp).sum);
}).add;

p = ~master.play(Pbind(
	\instrument, Pn(\pv, 1),
	\pvbuf, c,
	\time, 1.0,
	\ptenv, [Env(#[0.2, 0.3], #[0.7], -5)],
	\pan1env, [Env(#[-1, 1], #[1])],
	\env, [Env.linen(0.01, 0.98, 0.01)],
	\amp, 0.5
));


d = (
	hold: Pbind(
		// yes, I want both levels to be the same, so no {}
		\ptenv, Pfunc({ Env(Array.fill(2, rrand(0.0, 0.9)), #[1]) })
	),
	// fast!
	sweep: Pbind(
		\ptenv, Pfunc({ |ev|
			var pt1 = rrand(0.0, 0.9);
			Env([pt1, (pt1 + (rrand(0.1, 0.3) * BP(\ml).anglePoint.x * #[-3, 3].choose)).fold(0, 0.9)], #[1])
		})
	),
	sweepRev: Pbind(
		\ptenv, Pfunc({
			var t = rrand(0.1, 0.8),
			plus = rrand(0.1, 0.3) * BP(\ml).anglePoint.x * #[-3, 3].choose,
			pt1 = rrand(0.0, 0.9);
			Env([pt1, pt1 + plus, pt1 + (rrand(0.5, 0.8) * plus)], [t, 1-t], \sin)
		})
	),
	holdswp: Pbind(
		\ptenv, Pfunc({
			var pt1 = rrand(0.0, 0.9), hold = rrand(0.2, 0.6);
			Env([pt1, pt1, (pt1 + (rrand(0.1, 0.3) * #[-1, 1].choose)).wrap(0, 1)],
				[hold, 1 - hold], 5)
		})
	),
	swphold: Pbind(
		\ptenv, Pfunc({
			var pt1 = rrand(0.0, 0.9), hold = rrand(0.2, 0.6),
			pt2 = (pt1 + (rrand(0.1, 0.3) * #[-1, 1].choose)).wrap(0, 1);
			Env([pt1, pt2, pt2], [1 - hold, hold], -5)
		})
	)
);

Pdefn(\which, \sweep);
Pdefn(\which, Prand([Pn(\hold, { rrand(1, 6) }), \sweep, \sweepRev, \holdswp, \swphold], inf));

m = MixerChannel(\pv, s, 2, 2, outbus: ~master);
m => MCG(1);

p = m.play(
	Psym1(Pkey(\which), d)
	<>
	(q = PbindProxy(
		\which, Pdefn(\which),
		\instrument, \pv,
		\pvbuf, c,
		\delta, Pexprand(0.12, 0.8, inf),
		\time, Pkey(\delta) * Pexprand(0.7, 1.2, inf),
		\pan1env, Pfunc({ Env(Array.fill(2, { 1.0.rand2 }), #[1]) }),
		\panMul, Prand(#[-1, 1], inf),
		\panAdd, Pwhite(0.4, 0.7, inf) * Prand(#[-1, 1], inf),
		\env, [Env.perc(0.01, 0.98)],  // [Env.linen(0.01, 0.98, 0.01)],
		\amp, 0.5
	))
);

d[\hold] = Pbind(
		// yes, I want both levels to be the same, so no {}
	\ptenv, Pfunc({ Env(Array.fill(2, rrand(0.0, 0.9)), #[1]) }),
	\delta, Pexprand(0.07, 0.12, inf),
	\time, (Pkey(\delta) * Pexprand(0.5, 12.0, inf))
);

d[\sweep] = Pbind(
	\ptenv, Pfunc({ |ev|
		var pt1 = rrand(0.0, 0.9);
		Env([pt1, (pt1 + debug(rrand(0.1, 0.3) * BP(\ml).anglePoint.x * 3 * #[-1, 1].choose)).fold(0, 0.9)], #[1])
	})
);

Pdefn(\which, Pif(
	Pfunc({ BP(\ml).anglePoint.x.abs > 0.3 }),
	Pwxrand([Pn(\hold, { rrand(1, 6) }), \sweep, \sweepRev, \holdswp, \swphold], #[1, 3, 3, 3, 3].normalizeSum, inf),
	Pwxrand([Pn(\hold, { rrand(1, 6) }), \sweep, \sweepRev, \holdswp, \swphold], #[6, 1, 1, 1, 1].normalizeSum, inf)
));


Pdefn(\which, \sweepRev);

q.set(\delta, Pswitch1([
	Pexprand(0.1, 0.3, inf),
	Pexprand(0.8, 3.2, inf)
], Pfunc({ max(0, 0.7 - BP(\ml).normmag).debug.coin.binaryValue })));

q.set(\shiftenv, Pfunc({
	Env({ 30.rand2 } ! 2, #[1])
}));

q.set(\shiftenv, [Env.zero]);

q.set(\scramble, Pfunc({ Env(rrand(0.01, 0.99).debug("a") ! 2, #[1]) }));

q.set(\scramble, Pfunc({ |ev|
	if(ev[\time] > 0.7) { [Env([rrand(0.6, 0.9), 0], #[1], \sin)] }
	{ [Env.zero] }
}));

q.set(\scramble, Pfunc({ |ev|
	if(ev[\time] > 0.7) { [Env([0, rrand(0.6, 0.9)].rotate(0.7.rand.round.asInteger), #[1], rrand(1.5, 4.0))] }
	{ [Env.zero] }
}));

p.stop;


(
PR(\abstractProcess).clone({
	~event = (eventKey: \singleSynthPlayer);
	~normmagThresh = 0.4;
	~alwaysReset = true;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, outbus: topEnvironment[\master],
			completionFunc: { |chan| chan.newPostSend(topEnvironment[\rvbchan], 0.632) });
		~buf = Buffer.readAndQuery(s, topEnvironment[\dir] +/+ "samples/starbuckspv.aiff");
	};

	~freeCleanup = {
		[~chan, ~buf].free;
	};

	~preparePlay = {
		~listener = SimpleController(BP(\ml)).put(\allPtsReceived, e {
			if(BP(\ml).normmag >= ~normmagThresh) { ~reschedule.() };
		});
	};

	~stopCleanup = { ~listener.remove };

	~reschedule = {
		var oldESP = ~eventStreamPlayer;
		~eventStreamPlayer = EventStreamPlayer(~eventStream, ~eventStreamPlayer.event).refresh;
		~clock.sched(0, ~eventStreamPlayer);
		oldESP.stream = nil;
	};

	~dict = (
		hold: Pbind(
			// yes, I want both levels to be the same, so no {}
			\ptenv, Pfunc({ Env(Array.fill(2, rrand(0.0, 0.9)), #[1]) }),
			\delta, Pexprand(0.07, 0.12, inf),
			\time, (Pkey(\delta) * Pexprand(0.5, 12.0, inf))
		),
		// fast!
		sweep: Pbind(
			\ptenv, Pfunc({ |ev|
				var pt1 = rrand(0.0, 0.9);
				Env([pt1, (pt1 + (rrand(0.1, 0.3) * BP(\ml).anglePoint.x * #[-3, 3].choose)).fold(0, 0.9)], #[1])
			})
		),
		sweepRev: Pbind(
			\ptenv, Pfunc({
				var t = rrand(0.1, 0.8),
				plus = rrand(0.1, 0.3) * BP(\ml).anglePoint.x * #[-3, 3].choose,
				pt1 = rrand(0.0, 0.9);
				Env([pt1, pt1 + plus, pt1 + (rrand(0.5, 0.8) * plus)], [t, 1-t], \sin)
			})
		),
		holdswp: Pbind(
			\ptenv, Pfunc({
				var pt1 = rrand(0.0, 0.9), hold = rrand(0.2, 0.6);
				Env([pt1, pt1, (pt1 + (rrand(0.1, 0.3) * #[-1, 1].choose)).wrap(0, 1)],
					[hold, 1 - hold], 5)
			})
		),
		swphold: Pbind(
			\ptenv, Pfunc({
				var pt1 = rrand(0.0, 0.9), hold = rrand(0.2, 0.6),
				pt2 = (pt1 + (rrand(0.1, 0.3) * #[-1, 1].choose)).wrap(0, 1);
				Env([pt1, pt2, pt2], [1 - hold, hold], -5)
			})
		)
	);

	~which = Prand([Pn(\hold, { rrand(1, 6) }), \sweep, \sweepRev, \holdswp, \swphold], inf);
	~delta = Pexprand(0.12, 0.8, inf);
	~time = Pkey(\delta) * Pexprand(0.7, 1.2, inf);
	~pan1env = Pfunc({ Env(Array.fill(2, { 1.0.rand2 }), #[1]) });
	~panMul = Prand(#[-1, 1], inf);
	~panAdd = Pwhite(0.4, 0.7, inf) * Prand(#[-1, 1], inf);
	~env = [Env.perc(0.01, 0.98)];
	~amp = 0.5;

	~shiftenv = [Env.zero];
	~scramble = [Env.zero];

	// ~scramble = Pfunc({ Env(rrand(0.01, 0.99).debug("a") ! 2, #[1]) });

	// ~scramble = Pfunc({ |ev|
	// 	if(ev[\time] > 0.7) { [Env([rrand(0.6, 0.9), 0], #[1], \sin)] }
	// 	{ [Env.zero] }
	// });

	// ~scramble = Pfunc({ |ev|
	// 	if(ev[\time] > 0.7) { [Env([0, rrand(0.6, 0.9)].rotate(0.7.rand.round.asInteger), #[1], rrand(1.5, 4.0))] }
	// 	{ [Env.zero] }
	// });

	~asPattern = {
		Psym1(Pkey(\which), ~dict)
		<>
		Pbind(
			\which, BPStream(\which),
			\instrument, \pv,
			\pvbuf, c,
			\delta, BPStream(\delta),
			\time, BPStream(\time),
			\pan1env, BPStream(\pan1env),
			\panMul, BPStream(\panMul),
			\panAdd, BPStream(\panAdd),
			\env, BPStream(\env),
			\amp, BPStream(\amp),
			\scramble, BPStream(\scramble),
			\shiftenv, BPStream(\shiftenv)
		)
	};
}) => PR(\pv);
)

BP(\pv).free;
PR(\pv) => BP(\pv);
BP(\pv) => MT(1);
0 => BP(\pv);

BP(\pv).delta = Pswitch1([
	Pexprand(0.1, 0.3, inf),
	Pexprand(0.8, 3.2, inf)
], Pfunc({ max(0, 0.7 - BP(\ml).normmag).debug.coin.binaryValue }));

z = Prout({
	var count = rrand(1, 6), didPassThresh = false;
	while { count > 0 } {
		\hold.yield;
		count = count - 1;
		if(BP(\ml).normmag >= ~normmagThresh) {
			didPassThresh = true
		} {
			if(didPassThresh) { count = 0 };  // early exit
		};
	};
});

BP(\pv).which = Pif(
	Pfunc({ BP(\ml).anglePoint.x.abs > 0.3 }),
	Pwxrand([z, \sweep, \sweepRev, \holdswp, \swphold], #[1, 3, 3, 3, 3].normalizeSum, inf),
	Pwxrand([z, \sweep, \sweepRev, \holdswp, \swphold], #[6, 1, 1, 1, 1].normalizeSum, inf)
);


SynthDef(\bass, { |out, freq, freqlag = 0.5, gate = 1, amp = 0.1, det = 1.005,
	ffreq = 230, rq = 0.3, hpfreq = 300, hiAmp = 0.1,
	modbase = 0, modspike = 0, modfreq = 0.3, modfspike = 0, //t_modtrig = 0,
	rqdiv = 5|
	var	t_modtrig = NamedControl.tr(\t_modtrig, 0),
	sig = Saw.ar(Lag.kr(freq, freqlag) * [1, det], amp).sum,
	modtrig = Latch.kr(t_modtrig, t_modtrig),
	mt12 = modtrig * 0.12,
	gt0 = t_modtrig > 0,
	modfplus = Decay2.kr(gt0, mt12, modtrig, modfspike),
	modaplus = Decay2.kr(gt0, mt12, modtrig, modspike),
	ffmod = SinOsc.kr(modfreq + modfplus, 0).exprange(1, 1 + modbase + modaplus),
	rqspike = EnvGen.kr(Env([1, rqdiv, 1], [mt12, modtrig], -2.5), t_modtrig),
	eg = EnvGen.kr(Env.asr(0.1, 1, 8), gate, doneAction: 2),
	lpf, hpf, fft, fft2, pan1;
	lpf = RLPF.ar(sig, ffreq * ffmod, rq / rqspike);
	hpf = HPF.ar(sig, hpfreq);
	fft = FFT(LocalBuf(1024, 1), hpf);
	fft2 = PV_Copy(fft, LocalBuf(1024, 1));
	fft = PV_RandComb(fft /*<! fft2*/, 0.86, Dust.kr(0.05));
	fft2 = PV_RandComb(fft2, 0.86, Dust.kr(0.05)); // PV_MagSubtract(fft2, fft);
	pan1 = DemandEnvGen.kr(
		Dstutter(Diwhite(2, 9, inf), Dseq(#[-1, 1], inf)) * Dwhite(0.15, 1.0, inf),
		Dwhite(0, 1, inf).linexp(0, 1, 0.2, 0.7)
	);
	hpf = Pan2.ar(IFFT([fft, fft2]), [pan1, (LFNoise1.kr(0.09, 0.2) - pan1).fold(-1, 1)],
		hiAmp).sum;
	Out.ar(out, (lpf + hpf) * eg);
}).add;

a = m.play(\bass, [freq: 38.midicps, modbase: 0.6, modspike: 2, modfspike: 3, rqdiv: 5]);
a.trace;

a.set(\freq, 26.midicps);

a.set(\hiAmp, 0.4);

a.set(\modfspike, 18);
a.set(\modspike, 1.4);

a.set(\hpfreq, 400);

fork {
	a.set(\t_modtrig, 5);
	0.1.wait;
	a.trace;
};


a.release;

(1014..1016).do(s.sendMsg(\n_free, _))