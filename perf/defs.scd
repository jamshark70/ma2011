
if(~master.tryPerform(\isRunning) != true) {
	~master = MixerChannel(\master, s, 2, 2);
	if(MCG.exists(7)) { ~master => MCG(7) };
};

if(~rvbchan.tryPerform(\isRunning) != true) {
	~rvbchan = MixerChannel(\rvb, s, 2, 2, level: 2.sqrt, outbus: ~master, completionFunc: { |chan|
		~rvb = chan.playfx(Instr("busfx.freeverb2"), [0, 1.0, 0.69659996032715, 0.078699998557568, 1.0]);
	});
	if(MCG.exists(6)) { ~rvbchan => MCG(6) };
};

if(~hpchan.tryPerform(\isRunning) != true) {
	~hpchan = MixerChannel(\hp, s, 2, 2, level: 2.sqrt, outbus: ~rvbchan, completionFunc: { |chan|
		~hp = chan.playfx(
			Instr("busfx.hpf", { |bus, numChan = 1, freq|
				HPF.ar(In.ar(bus, numChan), freq)
			}, [\audiobus, StaticSpec(1, 8, \lin, 1), \freq]),
			[0, 2, 300]
		);
	});
	if(MCG.exists(5)) { ~hpchan => MCG(5) };
};


do((0..11)) { |i|
	var	name = i.asMIDINote(5).reject(_.isDecDigit).replace("#", "s").toLower.asSymbol;
	Mode(\default).v.copy.root_(i)/*.transposeRoot(2)*/ => Mode(name);
};


{ |bool = false|
	BP(\mg).win.alwaysOnTop = bool;
	"wmctrl -r \"GridFlow SDL\" -b %,above"
	.format(if(bool) { "add" } { "remove" })
	.unixCmd;
} => Func(\alwaysTop);

/*
\alwaysTop.eval(true);
\alwaysTop.eval(false);
*/


// UNBELIEVABLE what it took to get this working
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
	sig = Mix(blendOsc.(car_buf, car_buf + 1, [freq + (mod * freq), 0], car_buf.frac))
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


(
keys: #[master, hpchan],
make: { |name|
	var out;
	~cb = Buffer.allocConsecutive(8, s, 2048, 1);
	~mb = Buffer.alloc(s, 2048, 1);

	fork {
		var cond = Condition.new;
		~cb.do { |buf, i|
			// Department of Redundancy Department:
			// if I block this thread by cond.hang, it also blocks sendCollection
			// unless I fork a separate thread just for sendCollection
			// grrrrrrr...
			fork {
				buf.sendCollection(
					Signal.fill(buf.numFrames div: 2, { (i / ~cb.size).rand2 }).asWavetable,
					action: { cond.unhang });
			};
			cond.hang;  // ensure signal is sent before adding sine content
			buf.sine1(#[1, 0, 0.6] * (1 - (i / ~cb.size)), clearFirst: false);
			s.sync;
		};
		~collIndex.debug("buffers ready");
	};
	~mb.sine1(#[1]);

	~target = MixerChannel(name, s, 2, 2, level: -14.dbamp, outbus: ~master,
		completionFunc: { |chan|
			~target.newPostSend(~hpchan, 0.86);
		});

	out = Voicer(25, WrapInstr("osc2.fm2carpan"), [
		car_buf: ~cb.first.bufnum,  // by making this a number, modulation is allowed
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


PR(\abstractProcess).clone({
	~event = (type: \rest);

	~chords = [
		#[21, 25, 28, 31, 33],
		#[28, 31, 32, 36, 40],
		#[29, 33, 34, 37, 42],
		#[31, 36, 37, 40, 46],
		#[34.5, 38, 43, 44, 47]
	].flop;

	~changeChordMode = \patRejectLastN.eval(
		Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf), 6
	);
	~chordChangeBeats = Pwhite(8, 15, inf);

	~makeBlend = Plazy({ Env(#[0, 1], [rrand(0.4, 0.8)]) });
	~xIntervals = Pwhite(3, 6, inf);
	~yIntervals = Pwhite(1, 4, inf);

	~changeChords = { |inevent|
		var	size = ~model.tryPerform(\dim) ? 5;
		~oldMode = ~mode;
		~mode = ~changeChordModeStream.next(inevent);
		~oldChords = ~chords;
		~chords = Pseries(21, ~xIntervals, size).collect { |bass|
			Pseries(bass, ~yIntervals, size).asStream.all
		}.asStream.all;
		~blend = ~makeBlend.();
	};

	~asPattern = {
		~changeChordModeStream ?? { ~makeStreamForKey.(\changeChordMode) };
		~chordChangeBeatsStream ?? { ~makeStreamForKey.(\chordChangeBeats) };
		Prout({ |inevent|
			var beats;
			~oldChords = nil;
			loop {
				~changeChords.(inevent);
				if(~oldChords.isNil) { ~oldChords = ~chords };
				beats = ~chordChangeBeatsStream.next(inevent);
				beats.do {
					inevent = 1.yield;
				};
				if(beats.frac != 0) {
					inevent = beats.frac.yield;
				};
			};
		})
	};
}) => PR(\chordsAndModes);


(
PR(\abstractProcess).clone({
	~restEvent = Event.silent(1);
	~autoStopChildren = true;
	~prep = {
		~players = IdentityDictionary.new;
		~userprep.();
		currentEnvironment
	};

	// just in case I need something else here later
	~freeCleanup = {
		~userfree.();
	};

	~addStream = { |pattern, quant|
		var	esp = pattern.play(~clock, ~event, quant);
		~players.put(
			esp,
			SimpleController(esp).put(\stopped, e {
				~players.at(esp).remove;  // dump the dependant
				~players.removeAt(esp);
				~userRemoveStreamPlayer.(esp);
				// ~players.size.debug("got stopped notification, remaining");
			});
		);
		~userAddStreamPlayer.(esp);
		esp
	};
	
	~stopCleanup = {
		// note, can't use keysDo
		// the point of using keys.do is to iterate over a collection
		// that is independent of the collection from which items will be removed
		// have to do this now: if the SimpleController fires after 'free', kaboom
		if(~autoStopChildren ? true) {
			~players.keys.do { |esp|
				~players.at(esp).remove;  // release the SimpleController dependant
				~players.removeAt(esp);   // remove the esp from the collection
				esp.stop;
			};
		};
		~userStop.();
	};

	~asPattern = {
		Pn(~restEvent, inf)  // need a dummy to keep BP alive
	};
}) => PR(\streamTrack);
);


(
make: { |name|
	BP(name).free;
	PR(\streamTrack).chuck(BP(name), nil, (
		event: (eventKey: \voicerNote, midi: true, midiNoteToFreq: _.midicps),
		restEvent: (freq: #[], delta: 1, length: 1, gate: 1),
		model: ~model ?? { BP(\ml) },
		chProc: ~chProc ?? { BP(\cm) },
		alwaysReset: true,
		userprep: {
			~syncMax = GenericGlobalControl(\syncMax, nil, 0.3);
			~gridStreams = Array.newClear(~model.points.size);
			currentEnvironment
		},
		userfree: { ~syncMax.free },
		useGui: { |vpi| ~syncMax => VP(vpi) },

		// this should not answer video data if not playing
		preparePlay: {
			~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
		},
		userStop: { ~resp.remove },

		magThresh: 60000,
		pquant: 0.25,

		respond: {
			var pts, esp;
			pts = [(0..24), ~model.points/*[ind]*/].flop
			.sort { |a, b| a[1].mag.last > b[1].mag.last };
			if(~gridStreams[pts[0][0]].isNil and: { pts[0][1].mag.last >= ~magThresh }) {
				// pass the point to makePattern
				esp = ~addStream.(~makePattern.(pts[0][1], pts[0][0]), ~pquant);
				~gridStreams[pts[0][0]] = esp;
			};
		},

		freq: { |pt, i| ~chProc.chords[4 - (i % 5)][i div: 5] },
		oldFreq: { |pt, i|
			(~chProc.oldChords ?? { ~chProc.chords })[4 - (i % 5)][i div: 5]
		},
		// this is KICK-ASS responsive! stop moving and it all slows down
		delta: {
			Pexprand(0.1, 0.6, inf) * Pfunc({ ~model.normmag.linlin(0.0, 0.5, 8, 1, \minmax) })
		},
		quantize: Pfunc({ ~model.centroid.y * 0.5 + 0.5 }),
		length: Pkey(\delta) * Pexprand(0.8, 1.7, inf),
		gate: { |pt, i| Pgeom.fromEndpoints(0.8, 0.01, ~numEvents) },
		pan: Pfunc({ ~model.centroid.x }),
		mode: Pfunc({ ~chProc.mode }),
		modePat: { BPStream(\mode) },
		oldMode: Pfunc({ ~chProc.mode }),
		oldModePat: { BPStream(\oldMode) },
		blend: Pfunc({ |inval| ~chProc.blendStream.next(inval) ?? { 1 } }),
		mod_ratio: { rrand(1, 4) },
		mod_lev: Pfunc({ ~model.centroid.y.linlin(-1, 1, 6.0, 0.3) }),

		qcurve: -4,

		quantize: { ~syncMax },
		gate: { |pt, i|
			var n = rrand(2, 4), env, large = (~numEvents * 0.8).asInteger;
			env = Env(
				([0.8, 0.1] ! n).flat,
				[large, ~numEvents - large]
				.collect { |z, i| z.partition(n - i, 1) }
				.lace(n*2 - 1),
				~qcurve ?? { -4 }
			);
			Pseries(0, 1, ~numEvents).collect({ |i| env.at(i) })
		},

		calcNumEvents: { /*|pt, i|*/ (~model.normmag * 25).round.asInteger + 9 },

		makePattern: { |pt, i|
			~numEvents = ~calcNumEvents.(pt, i);  // bah, tired of passing everything as args
			Pbind(
				\oldMode, ~oldModePat.(pt, i),
				\mode, ~modePat.(pt, i),
				\oldDegree, ~oldFreq.(pt, i),
				\degree, ~freq.(pt, i),
				\blend, BPStream(\blend),
				\freq, Pfunc({ |ev|
					var	f0 = ev[\oldDegree].unmapMode(ev[\oldMode] ? ev[\mode]),
					f1 = ev[\degree].unmapMode(ev[\mode]);
					blend(f0, f1, ev[\blend])
				}),
				\mod_ratio, ~mod_ratio.(pt, i),
				\mod_lev, ~mod_lev.(pt, i),
				\quantize, ~quantize.(pt, i),
				\delta, ~delta.(pt, i).collect { |dur, ev|
					var	rounded = min(~pquant, dur.round(~pquant)) - (thisThread.beats % ~pquant);
					if(rounded < ~pquant) { rounded = rounded + ~pquant };
					dur.blend(rounded, ev[\quantize])
				},
				\length, ~length.(pt, i),
				\gate, ~gate.(pt, i),
				\pan, ~pan.(pt, i)
			)
		},
		userRemoveStreamPlayer: { |esp|
			~gridStreams = ~gridStreams.replace(esp, #[nil]);
		}
	));
	0.25 => BP(name);
}, type: \bp) => Fact(\repeaterBP);


(
make: { |name|
	BP(name).free;

	PR(\streamTrack).chuck(BP(name), nil, (
		// set ~model at chuck time
		event: (eventKey: \voicerNote),
		model: ~model ?? { BP(\ml) },
		chProc: ~chProc ?? { BP(\cm) },
		alwaysReset: true,
		pquant: 0.25,
		magThresh: 0.3,  // ??
		angleThresh: 0.6,  // radians
		maxPlayers: 8,
		rhoScale: 7.5,  // assuming anglePoint.rho peaking about 0.25
		restEvent: (freq: #[], delta: 1, length: 1, gate: 1),
		userprep: {
			~syncMax = GenericGlobalControl(\syncMax, nil, 1);
		},
		userfree: { ~syncMax.free },
		useGui: { |vpi| ~syncMax => VP(vpi) },

		preparePlay: {
			~angleDiffs = 0 ! 5;
			~angleI = 0;
			~prevAngle = 0;
			~changeChordModeStream ?? { ~makeStreamForKey.(\changeChordMode) };
			// if(~chords.isNil) { ~changeChords.() };
			~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
		},
		userStop: { ~resp.remove },

		respond: {
			var diff = ~model.anglePoint.theta - ~prevAngle,
			temp;
			if(diff.inclusivelyBetween(-pi, pi).not) { diff = (2pi - diff).wrap(-pi, pi) };
			~angleI = (~angleI + 1) % ~angleDiffs.size;
			~angleDiffs[~angleI] = diff;
			~prevAngle = ~model.anglePoint.theta;
			// heavier lifting only if we pass the threshold test
			if(~players.size < ~maxPlayers and: { ~model.normmag >= ~magThresh }) {
				temp = ~angleDiffs.copy;
				temp.remove(temp.minItem);
				temp.remove(temp.maxItem);
				if(temp.every(_.inclusivelyBetween(~angleThresh.neg, ~angleThresh))) {
					~addStream.(~makePattern.(), ~pquant);
				};
			};
		},

		xPat: { |pt, i|
			// yPat will reuse this
			~incrTempPolar = ~model.anglePoint.asPolar;
			Pseries(~model.centroid.x, cos(~incrTempPolar.theta) * ~incrTempPolar.rho, inf)
			.round.asInteger % ~model.dim
		},
		yPat: { |pt, i|
			var y = ~model.centroid.y, oldY,
			incr = sin(~incrTempPolar.theta) * ~incrTempPolar.rho,
			incrSign = (incr >= 0).binaryValue * 2 - 1,
			xdiff = Pdiff(Pkey(\x)).asStream;
			Prout({ |inval|
				loop {
					inval = (~model.dim - 1 - y.trunc.asInteger).yield;
					oldY = y;
					y = y - incr;
					// x is calculated by floats but passed here as integers
					// so this checks the actual x coordinate's movement
					if(xdiff.next(inval) == 0 and: { y.round == oldY.round }) {
						y = y - incrSign;
					};
					y = y % ~model.dim;
				}
			})
		},
		freq: { |pt, i|
			// well, I shouldn't need wrapAt but somehow 'y' is negative sometimes?? WTF??
			Pfunc({ |ev| ~chProc.chords.wrapAt(ev[\y]).wrapAt(ev[\x]) })
		},
		delta: { Pexprand(0.2, 0.9, ~numEvents) },
		// quantize: Pfunc({ ~model.centroid.y * 0.5 + 0.5 }),
		length: Pkey(\delta), // * Pexprand(0.8, 1.7, inf),
		// frozen at start time - may try following x coordinate
		pan: Pfunc({ ~model.centroid.x }),
		mode: Pfunc({ ~chProc.mode }),
		modePat: { BPStream(\mode) },
		mod_ratio: 1, // { rrand(1, 4) },
		mod_lev: Pfunc({ ~model.centroid.y.linlin(-1, 1, 1.6, 0.15) }),
		cbufMap: #[6.99, 0, -3.2].asSpec,
		car_buf: Pfunc({
			~cbufMap.map(~model.centroid.y * 0.5 + 0.5) + VC(\pl).env.cb.first.bufnum
		}),

		qcurve: -4,

		quantize: { ~syncMax },
		gate: 0.2,

		calcNumEvents: { /*|pt, i|*/ (~model.normmag * 25).round.asInteger + 9 },

		makePattern: { // |pt, i|
			~numEvents = ~calcNumEvents.()/*.(pt, i)*/;  // bah, tired of passing everything as args
			Pbind(
				\mode, ~modePat.()/*.(pt, i)*/,
				\x, ~xPat.()/*.(pt, i)*/,
				\y, ~yPat.()/*.(pt, i)*/,
				\freq, ~freq.()/*.(pt, i)*/,
				\mod_ratio, ~mod_ratio.()/*.(pt, i)*/,
				\mod_lev, ~mod_lev.()/*.(pt, i)*/,
				\quantize, ~quantize.()/*.(pt, i)*/,
				\delta, ~delta.()/*.(pt, i)*/.collect { |dur, ev|
					var	rounded = min(~pquant, dur.round(~pquant)) - (thisThread.beats % ~pquant);
					if(rounded < ~pquant) { rounded = rounded + ~pquant };
					dur.blend(rounded, ev[\quantize])
				},
				\length, ~length.()/*.(pt, i)*/,
				\gate, ~gate.()/*.(pt, i)*/,
				\pan, ~pan.()/*.(pt, i)*/,
				\car_buf, ~car_buf.()
			)
		}
	));
	0.25 => BP(name);
}, type: \bp) => Fact(\arpegBP);


PR(\abstractProcess).clone({
	~event = (type: \rest);

	~chords = [
		#[21, 25, 28, 31, 33],
		#[28, 31, 32, 36, 40],
		#[29, 33, 34, 37, 42],
		#[31, 36, 37, 40, 46],
		#[34.5, 38, 43, 44, 47]
	].flop;

	~changeChordMode = \patRejectLastN.eval(
		Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf), 6
	);
	~chordChangeBeats = Pwhite(8, 15, inf);

	~blendTime = Pwhite(1.2, 2.2, inf);
	~makeBlend = Plazy({ Env(#[0, 1], [rrand(0.4, 0.8)]) });
	~xIntervals = Pwhite(3, 6, inf);
	~yIntervals = Pwhite(1, 4, inf);

	~changeChords = { |inevent|
		var	size = ~model.tryPerform(\dim) ? 5;
		~oldMode = ~mode;
		~mode = ~changeChordModeStream.next(inevent);
		~oldChords = ~chords;
		~chords = Pseries(21, ~xIntervals, size).collect { |bass|
			Pseries(bass, ~yIntervals, size).asStream.all
		}.asStream.all;
		~oldChords ?? { ~oldChords = ~chords };
		~blend = ~makeBlend.();
	};

	~asPattern = {
		~changeChordModeStream ?? { ~makeStreamForKey.(\changeChordMode) };
		~chordChangeBeatsStream ?? { ~makeStreamForKey.(\chordChangeBeats) };
		~blendTimeStream ?? { ~makeStreamForKey.(\blendTime) };
		Prout({ |inevent|
			var beats;
			loop {
				~changeChords.(inevent);
				beats = ~chordChangeBeatsStream.next(inevent);
				beats.do {
					inevent = 1.yield;
				};
				if(beats.frac != 0) {
					inevent = beats.frac.yield;
				};
			};
		})
	};
}) => PR(\chordsAndModes);
