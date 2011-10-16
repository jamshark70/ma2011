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

s.boot;

"~/share/SC/quarks/dewdrop_lib/ddwChucklib/Prototypes/devPreMIDIcfg.scd".loadPath;
MIDIPort.init(~srcInports);

\makeEmptyMixer8.eval;

m = MixerChannel(\demo, s, 2, 2);
m => MCG(0);


// a variant: shorter notes
// flurries of faster notes --> pulse

WrapInstr("osc2.fm2carpan", { |pan = 0, gate = 1, mod_env, mod_vs = 0|
	mod_env = mod_env.dereference.value(gate, mod_vs);
	Pan2.ar(
		WrapInstr.wrap("osc2.fm2car", [
			nil, gate, nil, mod_env, nil, nil, nil, nil, nil, nil, nil,
			mod_vs
		]),
		pan
	)
}, [\bipolar, #[0, 1], EnvSpec(Env.one), #[0, 1]]);


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
	~cb = Buffer.alloc(s, 2048, 1);
	~mb = Buffer.alloc(s, 2048, 1);

	~cb.sine1(#[1, 0, 0.6]);
	~mb.sine1(#[1]);

	~target = MixerChannel(name, s, 2, 2, level: -14.dbamp /*, completionFunc: {} */);

	out = Voicer(25, WrapInstr("osc2.fm2carpan"), [
		car_buf: ~cb, mod_buf: ~mb,
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
g.gui;

p = Pbind(
	\type, \voicerNote,
	\voicer, VC(\pl).v,
	\degree, Pxrand((-7 .. 7), inf),
	\root, 2,
	\dur, Pexprand(0.065, 0.2, inf).collect { |dur|
		// almost: sometimes notes are very short, sounds like polyphony
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

