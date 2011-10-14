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

m = MixerChannel(\demo, s, 2, 2);
MixingBoard(\demo, nil, m);

"~/share/SC/quarks/dewdrop_lib/ddwChucklib/Prototypes/devPreMIDIcfg.scd".loadPath;
MIDIPort.init(~srcInports);

MixerMIDIControl(\omni, nil, m);


BP(\ml).points[0].listVars

~makeLagDef = { |numChan = 1|
	SynthDef("lags" ++ numChan, { |bus, lagtime = 0.15|
		var	sig = In.kr(bus, numChan);
		ReplaceOut.kr(bus, VarLag.kr(sig, lagtime));
	}).add;
};

// magnitude, angle
~lagDef = ~makeLagDef.(BP(\ml).points.size * 2);

~dataBus = Bus.control(s, BP(\ml).points.size * 2);

~lags = Synth(~lagDef.name, [bus: ~dataBus], m.fadergroup, \addToHead);
~lags.run(false);
~lags.run(true);

SynthDef(\blips, { |databus, magThresh = 100, magDivisor = 200000, decayTime = 3, tfLow = 0.2, tfHigh = 12, freq = 440, graindur = 0.07, amp = 0.1, trigCycles = 20, pan, outbus|
	var	mag, angle, magdiff, bigtrig, decay, trigFreq, trig, ampenv, sig;
	#mag, angle = In.kr(databus, 2);
	// magdiff = HPZ1.kr(mag);
	bigtrig = Trig.kr(mag > magThresh, dur: trigCycles * ControlDur.ir);
	decay = Decay.kr(min(bigtrig * mag / magDivisor, 1), decayTime);
	trigFreq = decay.linlin(0, 1, tfLow, tfHigh, clip: \none) * (decay >= 0.001);
	trig = Impulse.ar(trigFreq);
	ampenv = EnvGen.ar(Env.perc(0.005, graindur), trig);
	sig = SinOsc.ar(freq, 0, amp) * ampenv;
	sig = Pan2.ar(sig, pan);
	Out.ar(outbus, sig);
}).add;

a = m.play(\blips, [databus: ~dataBus.index + (12*2), magThresh: 80000]);
a.trace;

a.set(\magDivisor, 100000);

a.set(\trigCycles, 3);

a.free;

f = 110;
a = BP(\ml).points.collect { |pt, i|
	var x = i div: 5, y = 4 - (i % 5);
	m.play(\blips, [
		databus: ~dataBus.index + (i*2),
		magThresh: 80000, magDivisor: 100000,
		freq: f * (x + 1) * ((y * 0.25) + 1),
		tfHigh: 7, graindur: 0.8/7,
		trigCycles: 3,
		pan: x.linlin(0, 4, -1, 1),
		amp: 1
	]);
};

~pid = "recordmydesktop -x 745 -y 49 --width 320 --height 556 --no-sound -o %/out.ogv".format(thisProcess.nowExecutingPath.dirname).unixCmd;
m.startRecord;

// WAIT after doing this! recordmydesktop needs to encode the ogv
"kill %".format(~pid).postln.unixCmd;
m.stopRecord;

MixingBoard.at(0).w.bounds
BP(\mg).win.bounds

Window.screenBounds.height - MixingBoard.at(0).w.bounds.bottom
Window.screenBounds.height - BP(\mg).win.bounds.top

BP(\ml).points[12].listVars

BP(\ml).points.do { |pt| [pt.x_origin, pt.y_origin].postln }; ""

.mag.mean

u = SimpleController(BP(\ml));
u.put(\allPtsReceived, nil);

u.put(\allPtsReceived, {
	topEnvironment[\dataBus].setn(BP(\ml).points.collect({ |pt| [pt.mag.mean, pt.angle] }).flat)
});


x = 0;
u.put(\allPtsReceived, {
	var x2 = BP(\ml).points[12].mag.mean;
	(x2 - x).postln;
	x = x2;
});

20000 / (0.15 * 44100 / 64)




// what the hell, i'll stash more dev code in here too

// slow swells - use adsr and release when a cell falls below threshold

~cb = Buffer.alloc(s, 2048, 1);
~mb = Buffer.alloc(s, 2048, 1);

~cb.sine1(#[1]);
~mb.sine1((1..10).reciprocal);

~cb.sine1((1..10).reciprocal);
~mb.sine1(#[1]);

Library.at(WrapInstr, \osc2).keys

// hack: pass gate and mod_vs to mod_env
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

WrapInstr("osc2.fm2carpan").listArgs

WrapInstr("osc2.fm2car").openFile;


v = WrapInstr("osc2.fm2carpan").miditest(0, [
	car_env: Env.adsr(0.8, 0.4, 0.6, 2.8),
	mod_env: `{ |gate|
		// maybe NamedControl for time sensitivity?
		Env([1, gate.linlin(0, 1, 1, 1.6), 1], [gate.linexp(0, 1, 2, 0.2), gate.linexp(0, 1, 3.3, 0.7)])
	},
	car_buf: ~cb, mod_buf: ~mb,
	mod_lev: 1.8037946271776,
	mod_ratio: 4,
	detune: -0.19685039370079,
	car_detune: 1.0052043765621,
	car_vs: 0.79527559055118,
	mod_vs: 0.37795275590551,
	basefreq: 440,
	keyscale: 0.33736499154165,
], target: m);

v.nodes[0].insp

a = {
	var	x = DC.kr(0.5),
		t = Impulse.kr(0);
	x.linlin(0, 1, [1, 2], [2, 4]).poll(t);
	FreeSelf.kr(t <= 0);
	0
}.play;


p = Pbind(
	\type, \voicerNote,
	\voicer, v,
	\degree, Pwhite(-7, 7, inf) + 21,
	\dur, 3,
	\legato, 0.75,
	\gate, 0.8
).play;

p.stop;


// Mode(\default).v.copy.root_(2) => Mode(\d);

(
(
make: { |name|
	var	out, argnames, argspecs;
	~cb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
		buf.sine1Msg((1..10).reciprocal);
	});
	~mb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
		buf.sine1Msg(#[1]);
	});

	~target = MixerChannel(name, s, 2, 2, level: -14.dbamp);

	// hack: pass gate and mod_vs to mod_env
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

	out = Voicer(40, WrapInstr("osc2.fm2carpan"), [
		car_env: Env.adsr(0.8, 0.4, 0.6, 2.8),
		mod_env: `{ |gate|
			// maybe NamedControl for time sensitivity?
			Env([1, gate.linlin(0, 1, 1, 1.6), 1], [gate.linexp(0, 1, 2, 0.2), gate.linexp(0, 1, 3.3, 0.7)])
		},
		car_buf: ~cb, mod_buf: ~mb,
		mod_lev: 1.8037946271776,
		mod_ratio: 4 //,
		// detune: -0.19685039370079,
		// car_detune: 1.0052043765621,
		// car_vs: 0.79527559055118,
		// mod_vs: 0.37795275590551,
		// basefreq: 440,
		// keyscale: 0.33736499154165
	], target: ~target);

	argnames = out.nodes[0].patch.argNames;
	argspecs = IdentityDictionary.new;
	out.nodes[0].patch.argSpecs.do { |spec, i|
		argspecs.put(argnames[i], spec)
	};

	[
		detune: -0.19685039370079,
		car_detune: 1.0052043765621,
		car_vs: 0.79527559055118,
		mod_vs: 0.37795275590551,
		basefreq: 440,
		keyscale: 0.33736499154165,
	].pairsDo { |name, value|
		out.mapGlobal(name, nil, value, argspecs[name]);
	};
	out
},
free: { [~target, ~cb, ~mb].free },
type: \voicer) => Fact(\fmswells);
)

(
BP(\swells).free;
if(Mode.exists(\dmixo).not) {
	ModalSpec(#[0, 2, 4, 5, 7, 9, 10], 12, 2) => Mode(\dmixo);
};

Proto({
	~event = (eventKey: \voicerNote, immediateOSC: true);
	~mode = \dmixo;
	~model = BP(\ml);
	// try to make vertical and horizontal work as sonorities
	// only the middle one is cheezy
	~chords = [
		#[21, 25, 28, 31, 33],
		#[28, 31, 32, 36, 40],
		#[29, 33, 34, 37, 42],
		#[31, 36, 37, 40, 46],
		#[34.5, 38, 43, 44, 47]
	];

	~prep = {
		~event.parent = ProtoEvent(\voicerNote).v.parent;
		~resp = SimpleController(~model).put(\allPtsReceived, e {
			~respond.();
		});
		~gridNodes = Array.fill(~model.points.size, nil);
		currentEnvironment
	};

	~freeCleanup = {
		~resp.remove;
	};

	~respond = {
		var ind = ~gridNodes.collectIndicesOfItem(nil),
			pts, ev;
		if(ind.size > 0) {
			pts = [ind, ~model.points[ind]].flop.sort { |a, b| a[1].mag.last > b[1].mag.last };
			ind = pts[0][0];
			ev = ~event.copy.putAll((
				freq: ~chords[ind % 5][ind div: 5],
				mode: ~mode,
				delta: 1,
				length: 2,
				gate: 0.1,
				pan: 0
			)).play;
			pts = nil;
			~gridNodes[ind] = ev.nodes[0];
			OSCFunc(OSCArgsMatcher([ev.nodes[0].synth.nodeID.debug("nodeid")], e {
				~gridNodes[ind] = nil;  // free up to play again
			}), '/n_end', s.addr).oneShot;
		};
	};
}) => BP(\swells);
)

VC(\fms).free;
Fact(\fmswells) => VC(\fms);
VC(\fms) => BP(\swells);


p = Pbind(
	\voicer, VC(\fms).v,
	\freq, Pseq(~chords, 1),
	// \freq, Pseq(~chords.flop, 1),
	\mode, \dmixo,
	\delta, 4,
	\length, 2.5,
	\gate, 0.5
).play(protoEvent: ProtoEvent(\voicerNote).copy);

p.stop;

ProtoEvent(\voicerNote).copy
			ev = (
				freq: ~chords[ind % 5][ind div: 5],
				mode: ~mode,
				delta: 1,
				length: 2,
				gate: 0.1,
				pan: 0
			).play;
