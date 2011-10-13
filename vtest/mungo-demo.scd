(
var dir;

if(Func.exists(\ma2011dir)) {
	dir = \ma2011dir.eval;
} {
	Error("Func(\\ma2011dir) doesn't exist. Check your startup configuration (instructions in addToYourStartupFile.scd).").throw;
};

(dir +/+ "perf/loadVideo.scd").loadPath;
)

s.boot;

m = MixerChannel(\demo, s, 2, 2);
MixingBoard(\demo, nil, m);

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

WrapInstr("osc2.fm2carpan", { |pan = 0|
	Pan2.ar(WrapInstr.wrap("osc2.fm2car"), pan)
}, [\bipolar]);

WrapInstr("osc2.fm2carpan").listArgs

WrapInstr("osc2.fm2car").openFile;

( channel: 0, initArgs, target, bus, ctlChannel, makeVoicerFunc )

MIDIPort.init;

v = WrapInstr("osc2.fm2carpan").miditest(0, [
	car_env: Env.adsr(0.8, 0.4, 0.6, 2.8),
	// nil, // mod_env: Env.adsr( attackTime: 0.01, decayTime: 0.3, sustainLevel: 0.5, releaseTime: 1, peakLevel: 1, curve: -4, bias: 0 )
	car_buf: ~cb, mod_buf: ~mb
], target: m);

v.nodes[0].insp


p = Pbind(
	\type, \voicerNote,
	\voicer, v,
	\degree, Pwhite(-7, 7, inf) + 21,
	\dur, 3,
	\legato, 0.75,
	\gate, 0.8
).play;

p.stop;

\pan, 0, 
\mod_lev, 1.028059363652, 
\mod_ratio, 2, 
\detune, 0.61800003051758, 
\car_detune, 1.0028868434838, 
\car_vs, 0, 
\mod_vs, 0, 
\basefreq, 440, 
\keyscale, 0.28880180238151, 
