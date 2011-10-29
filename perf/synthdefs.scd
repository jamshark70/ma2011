~addSel = if(SynthDef.findRespondingMethodFor(\add).notNil) { \add } { \memStore };

~ebuf = Buffer.sendCollection(s, Env.perc(0.01, 0.99).asSignal(512));

SynthDef(\keys, { |gateThresh = 0.1995 /* -14.dbamp */, thresh = 0.15|
	var	in = CompanderD.ar(SoundIn.ar(0), gateThresh, slopeBelow: 10, slopeAbove: 1),
	fft = FFT(LocalBuf(512, 1), in),
	trig = Onsets.kr(fft, thresh);
	SendReply.kr(trig, '/keystroke');
}).perform(~addSel);

SynthDef(\masterLimiter, {
	ReplaceOut.ar(0, Limiter.ar(In.ar(0, 2)));
}).perform(~addSel);


SynthDef(\linmap, { |inbus, outbus, inMin, inMax, outMin, outMax|
	ReplaceOut.kr(outbus,
		In.kr(inbus, 1).linlin(inMin, inMax, outMin, outMax)
	);
}).perform(~addSel);

SynthDef(\expmap, { |inbus, outbus, inMin, inMax, outMin, outMax|
	ReplaceOut.kr(outbus,
		In.kr(inbus, 1).linexp(inMin, inMax, outMin, outMax)
	);
}).perform(~addSel);


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
}).perform(~addSel);



SynthDef(\aps, { |out, bufnum, t_trig = 0, gate = 1, attack = 0.01, susLev = 1, release = 0.5,
	start = 0, rate = 1, amp = 0.1, dcyMul = 1, apdecay = 1, topaplevel = 0.25, drylev = 1,
	balance = 0, balance2 = 0, balMoveTime = 1|
	var sig = Normalizer.ar(PlayBuf.ar(1, bufnum, startPos: start, rate: rate, loop: 1), 0.9),
	sum = 0,
	delayscale = MouseX.kr(1, 0.08, lag: 0.1),
	aplevel = MouseY.kr(0, topaplevel, lag: 0.1),
	// transfer function to fade in the allpasses at different rates
	apEnvs = Array.fill(3, { |i|
		InterplEnv(#[0, 0, 1], [i/3, 1/3], \sin)
	}),
	sensitivity = 1 - min(1, Decay2.kr(t_trig, 0.01, TRand.kr(1.0, 6.0, t_trig) * dcyMul)),
	eg = EnvGen.kr(Env.asr(attack, susLev, release, #[4, -4]), gate, doneAction: 2);
	3.do { |i|
		var level = IEnvGen.kr(apEnvs[i], aplevel);
		sum = sum + AllpassL.ar(if(i == 0) { sig } { sum },
			maxdelaytime: 0.1,
			delaytime: LFNoise1.kr(
				{ Rand(2.0, 5.0) }.dup,
				{ Rand(0.02, 0.038) }.dup * delayscale,
				{ Rand(0.04, 0.05) }.dup * delayscale
			),
			decaytime: apdecay,
			mul: (level - 1) * sensitivity + 1
		);
	};
	sum = Balance2.ar(sum[0], sum[1], Line.kr(balance, balance2, balMoveTime));
	sig = LeakDC.ar(sig * drylev + sum);
	Out.ar(out, sig * eg * amp)
}).perform(~addSel);


SynthDef(\combs, { |out, bufnum, t_trig = 0, gate = 1, attack = 0.01, susLev = 1, release = 0.5,
	start = 0, rate = 1, amp = 0.1, dcyMul = 1, apdecay = 1, topaplevel = 0.25, drylev = 1,
	balance = 0, balance2 = 0, balMoveTime = 1|
	var sig = Normalizer.ar(PlayBuf.ar(1, bufnum, startPos: start, rate: rate, loop: 1), 0.9),
	sum = 0,
	delayscale = MouseX.kr(1, 0.08, lag: 0.1),
	aplevel = MouseY.kr(0, topaplevel, lag: 0.1),
	// transfer function to fade in the allpasses at different rates
	apEnvs = Array.fill(3, { |i|
		InterplEnv(#[0, 0, 1], [i/3, 1/3], \sin)
	}),
	sensitivity = 1 - min(1, Decay2.kr(t_trig, 0.01, TRand.kr(1.0, 6.0, t_trig) * dcyMul)),
	eg = EnvGen.kr(Env.asr(attack, susLev, release, #[4, -4]), gate, doneAction: 2);
	3.do { |i|
		var level = IEnvGen.kr(apEnvs[i], aplevel);
		sum = sum + CombL.ar(if(i == 0) { sig } { sum },
			maxdelaytime: 0.1,
			delaytime: LFNoise1.kr(
				{ Rand(2.0, 5.0) }.dup,
				{ Rand(0.02, 0.038) }.dup * delayscale,
				{ Rand(0.04, 0.05) }.dup * delayscale
			),
			decaytime: apdecay,
			mul: (level - 1) * sensitivity + 1
		);
	};
	sum = Balance2.ar(sum[0], sum[1], Line.kr(balance, balance2, balMoveTime));
	sig = LeakDC.ar(sig * drylev + sum);
	sig = Limiter.ar(sig * amp, 0.9);
	Out.ar(out, sig * eg)
}).perform(~addSel);


~makeLagDef = { |numChan = 1|
	SynthDef("lags" ++ numChan, { |inbus, outbus, lagtime = 0.15|
		var	sig = In.kr(inbus, numChan),
		trigs = HPZ1.kr(sig).abs > 0,
		envs = sig.asArray.collect { |chan, i|
			EnvGen.kr(Env([chan, chan], [lagtime]), trigs[i])
		};
		ReplaceOut.kr(outbus, envs);
	}).perform(topEnvironment[\addSel]);
};

~makeLagDef.(5);


~mappedData = IdentityDictionary.new;
~ctlNums = (x: 0, y: 1, theta: 2, rho: 3, mag: 4, angle: 2, radius: 3, rad: 3, mx: 5, mouseX: 5, my: 6, mouseY: 6);
~map = { |synth, name, ctlName, inMin, inMax, outMin, outMax, curve(\lin), source(~lagbus)|
	var synthmaps, mapping;
	if(synth.isKindOf(Synth)) {
		~unmap.(synth, name);
		synthmaps = ~mappedData[synth];
		if(synthmaps.isNil) {
			synthmaps = IdentityDictionary.new;
			~mappedData[synth] = synthmaps;
		};
		synthmaps.put(name, List.new);
		mapping = IdentityDictionary.new;
		mapping[\bus] = Bus.control(s, 1);
		mapping[\ctlname] = ctlName;
		mapping[\mapsynth] = Synth(curve ++ "map",
			[
				inbus: source.index + (~ctlNums[name] ? 0),
				outbus: mapping[\bus]
			] ++ [#[inMin, inMax, outMin, outMax], [inMin, inMax, outMin, outMax]].flop.flat,
			target: s.asTarget, addAction: \addBefore
		);
		mapping[\listener] = Updater(synth, { |node, what|
			if(what == \n_end) {
				mapping[\listener].remove;
				topEnvironment.use { ~unmap.(synth, name) }
			};
		});
		synth.map(ctlName, mapping[\bus]);
		synth.register;
		synthmaps[name].add(mapping);
		mapping
	};
};

~unmap = { |synth, name|
	var synthmaps;
	if((synthmaps = ~mappedData[synth]).notNil) {
		synthmaps[name].do { |mapping|
			if(synth.isPlaying) { synth.map(mapping[\ctlname], -1) };
			mapping[\mapsynth].free;
			mapping[\bus].free;
			mapping[\listener].remove;
		};
		synthmaps.removeAt(name);
		if(synthmaps.size == 0) { ~mappedData.removeAt(synth) };
	};
};


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


SynthDef(\normbufplay, { |bufnum, out, rate = 1, start = 0|
	Out.ar(out, Normalizer.ar(PlayBuf.ar(1, bufnum, rate: rate, startPos: start, loop: 1)))
}).add;


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
