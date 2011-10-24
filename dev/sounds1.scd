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
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
	* EnvGen.kr(mod_env, gate);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];
	sig = Mix(VOsc.ar(car_buf, freq + (mod * freq), 0, car_amp))
	* EnvGen.kr(car_env, gate, doneAction:2)
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
			// god DAMN it I hate using temp diskfiles
			// but it isn't safe to block the thread when using sendCollection
			// fuck fuck fuck fuck fuck
			buf.loadCollection(
				Signal.fill(buf.numFrames div: 2, { (i / ~cb.size).rand2 }).asWavetable,
				action: { cond.unhang });
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

