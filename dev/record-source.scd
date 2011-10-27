

m = MixerChannel(\rec, s, 2, 2, outbus: 14);

a = m.play { SoundIn.ar([0, 1]) };

"mkdir %/samples".format(thisProcess.nowExecutingPath.dirname.dirname).unixCmd;

m.startRecord(thisProcess.nowExecutingPath.dirname.dirname +/+ "samples/starbucks.aiff");

m.stopRecord;

m.free;


// oh hey, why not, everything else is fucking going wrong
// of COURSE the DC-offset removal plugin would disappear from Audacity!!
// Couple of clicks, vs writing some nrt code
// just kill me now. We're doomed.
(
d = thisProcess.nowExecutingPath.dirname.dirname;

f = SoundFile.openRead(d +/+ "samples/starbucks.aiff");
f.close;

x = Score.new;
b = Buffer.new;
x.add([0, b.allocReadMsg(d +/+ "samples/starbucks.aiff")]);
x.add([0, ["/d_recv", SynthDef("leakdc2", { |bufnum|
	var frames = BufFrames.kr(bufnum),
		phase = Phasor.ar(0, rate: 1, start: 0, end: frames+1000),
		sig = BufRd.ar(2, bufnum, phase, loop: 0, interpolation: 2);
	sig = LeakDC.ar(sig);
	Out.ar(0, sig);
	FreeSelf.kr(A2K.kr(phase) >= frames);
}).asBytes]]);
x.add([0, Synth.basicNew("leakdc2", s, 1000).newMsg(s, [bufnum: b.bufnum])]);
x.add([f.duration, b.freeMsg]);

x.recordNRT(d +/+ "osctemp", d +/+ "samples/starbucks2.aiff", sampleFormat: "float", options: ServerOptions.new.numOutputBusChannels_(2), action: { "done".postln });
)


// b = Buffer.readAndQuery(s, d +/+ "samples/starbucks2.aiff");

b = Buffer.readChannel(s, d +/+ "samples/starbucks2.aiff", channels: #[0]);

a = ~master.play {
	var trig = Impulse.ar(15),
	dur = 4/15,
	pos = Phasor.kr(0, 0.1 / BufDur.kr(b), start: 0, end: 1),
	rate = SinOsc.kr(0.1).exprange(0.1, 10);
	GrainBuf.ar(2, trig, dur, b, rate, pos);
};

a.free;

a.trace;

a = ~master.play { |prob = 0.5|
	var sig = PlayBuf.ar(1, b, rate: 1, loop: 1),
	fft = FFT(LocalBuf(1024, 1), sig),
	trig = fft >= 0;
	// fft = PV_MagShift(fft, SinOsc.kr(0.1).exprange(1, 8));
	// fft = PV_RandComb(fft, TRand.kr(0, 1, trig) < 0.5);
	fft = PV_RandComb(fft, prob, Dust.kr(0.2));
	IFFT(fft)
};

a.free;

u.remove;
u = SimpleController(BP(\ml)).put(\allPtsReceived, {
	a.set(\prob, max(0, 0.95 - (BP(\ml).normmag * 2)).postln);
});

a.trace



a = ~master.play { |prob = 0.5, t_trig = 1|
	var sig = Normalizer.ar(PlayBuf.ar(1, b, rate: 1, loop: 1), 0.95),
	fft = FFT(LocalBuf(1024, 1), sig),
	fft2 = PV_Copy(fft, LocalBuf(1024, 1)),
	// fbTime = LocalIn.kr(1),
	// dust = Impulse.kr(fbTime.reciprocal), // Dust.kr(0.2),
	panTarget = ToggleFF.kr(t_trig),
	fbTime = TRand.kr(0.5, 2.0, t_trig),
	gate = Trig1.kr(t_trig, fbTime),
	prevtrig = Delay1.kr(t_trig),
	gap = (t_trig >= 1) * (prevtrig <= 0) * (gate >= 1),
	pan = EnvGen.ar(Env(panTarget ! 3, [fbTime, ControlDur.ir], releaseNode: 1), gate - gap);
	fft = PV_RandComb(fft <! fft2, prob, t_trig * (panTarget <= 0));
	fft2 = PV_RandComb(fft2, prob, t_trig * (panTarget >= 1));
	XFade2.ar(IFFT(fft), IFFT(fft2), pan.madd(2, -1)) ! 2
};

a.set(\prob, 0.9);

a.free;

	trig = fft >= 0;
	// fft = PV_MagShift(fft, SinOsc.kr(0.1).exprange(1, 8));
	// fft = PV_RandComb(fft, TRand.kr(0, 1, trig) < 0.5);
	fft = PV_RandComb(fft, prob, Dust.kr(0.2));


"notify-send -t 1500 'hi mungo'".unixCmd(nil, false);