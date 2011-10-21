
// crap. doesn't work b/c 'nexttime' is already decided in the Spawner
// can't move 'nexttime' earlier...

p = Pspawner({ |sp|
	x = sp;
	loop { sp.now.debug("time"); sp.wait(1) };
}).play(quant: 1);

q = p.stream;

x.par(Pn((play: { x.now.debug("\tevent") }), 1), 0.5);
p.stop;
p = EventStreamPlayer(q, Event.default).play(quant: [1, 0.5]);

p.stop;


// don't pull them into the spawner:
// run them separately and track their endings

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
)

(
BP(\st).free;

if(Mode.exists(\d).not) { ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 2) => Mode(\d) };

PR(\streamTrack).chuck(BP(\st), nil, (
	event: (eventKey: \voicerNote, midi: true, midiNoteToFreq: _.midicps),
	restEvent: (freq: #[], delta: 1, length: 1, gate: 1),
	model: BP(\ml),
	alwaysReset: true,
	userprep: {
		~syncMax = GenericGlobalControl(\syncMax, nil, 0.3);
		~gridStreams = Array.newClear(~model.points.size);
		~oldChords = ~chords;
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
	// lastCentroid: Point(0, 0),
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

	chords: [
		#[21, 25, 28, 31, 33],
		#[28, 31, 32, 36, 40],
		#[29, 33, 34, 37, 42],
		#[31, 36, 37, 40, 46],
		#[34.5, 38, 43, 44, 47]
	].flop,

	// centroid x
	// centroid y
	
	// sync target, sync range, sync time
	// pitch (most active pt)

	freq: { |pt, i| ~chords[4 - (i % 5)][i div: 5] },
	oldFreq: { |pt, i| (~oldChords ? ~chords)[4 - (i % 5)][i div: 5] },
	delta: { Pexprand(0.1, 0.6, inf) },
	quantize: Pfunc({ ~model.centroid.y * 0.5 + 0.5 }),
	length: Pkey(\delta) * Pexprand(0.8, 1.7, inf),
	gate: { |pt, i| Pgeom.fromEndpoints(0.8, 0.01, ~numEvents) },
	pan: Pfunc({ ~model.centroid.x }),
	mode: \d,
	modePat: { BPStream(\mode) },
	blend: 1,
	mod_ratio: { rrand(1, 4) },
	mod_lev: Pfunc({ ~model.centroid.y.linlin(-1, 1, 6.0, 0.3) }),

	qcurve: -4,
	// tried it, didn't like it - effect was not clear
	// quantize: { |pt, i|
	// 	var env = Env([0, ~syncMax.value], [1], ~qcurve), p;
	// 	p = Pseries.fromEndpoints(0, 1, (~numEvents * 0.75).asInteger).collect { |i| env.at(i) };
	// },

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
0.25 => BP(\st);
if(VC.exists(\pl)) { VC(\pl) => BP(\st) };
)

BP(\st) => MT(1);
BP(\st) => VP(0);

BP(\st).stop;
BP(\st).play;
BP(\st).isPlaying;

BP(\st).gridStreams = Array.newClear(25);

BP(\st).qcurve = -4;
BP(\st).quantize = { |pt, i|
	var env = Env([0, ~syncMax.value], [1], ~qcurve), p;
	p = Pseries.fromEndpoints(0, 1, (~numEvents * 0.75).asInteger).collect { |i| env.at(i) };
};

BP(\st).quantize = { ~syncMax };
BP(\st).gate = { |pt, i|
	var n = rrand(2, 4), env, large = (~numEvents * 0.8).asInteger;
	env = Env(
		([0.8, 0.1] ! n).flat,
		[large, ~numEvents - large]
			.collect { |z, i| z.partition(n - i, 1) }
			.lace(n*2 - 1),
		~qcurve ?? { -4 }
	);
	Pseries(0, 1, ~numEvents).collect({ |i| env.at(i) })
};


Mode(\d).v.transposeRoot(newRoot: 0).postcs
Mode(\default).v.copy.root_(4).postcs.transposeRoot(2).postcs

do((0..11)) { |i|
	var	name = i.asMIDINote(5).reject(_.isDecDigit).replace("#", "s").toLower.asSymbol;
	Mode(\default).v.copy.root_(i).transposeRoot(2) => Mode(name);
};

do((0..11)) { |i|
	var	name = i.asMIDINote(5).reject(_.isDecDigit).replace("#", "s").toLower.asSymbol;
	Mode(\default).v.copy.root_(i)/*.transposeRoot(2)*/ => Mode(name);
};

// kind of weird Gavin Bryars-y thing going on here
BP(\st).mode = Pstutter(Pwhite(100, 190, inf), Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf).trace);

#[a, as, b, c, cs, d, ds, e, f, fs, g, gs].do { |key| [key, Mode(key).v.asCompileString].postln };

BP(\st).v[\asPattern].postcs
BP(\st).origChords = BP(\st).chords;

BP(\st).chordChangeBeats = Pwhite(12, 20, inf);
BP(\st).asPattern = {
	~chordChangeBeatsStream ?? { ~makeStreamForKey.(\chordChangeBeats) };
	Prout({ |inevent|
		var beats;
		loop {
			~changeChords.(inevent);
			beats = ~chordChangeBeatsStream.next(inevent);
			beats.do {
				inevent = 1.yield;
			};
			if(beats.frac != 0) { inevent = beats.frac.yield };
		};
	})
};

BP(\st).changeChordMode = \patRejectLastN.eval(Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf), 6);
BP(\st).xIntervals = Pwhite(3, 6, inf);
BP(\st).yIntervals = Pwhite(1, 4, inf);

BP(\st).changeChords = { |inevent|
	~oldMode = ~mode;
	~mode = ~changeChordModeStream.next(inevent);
	~oldChords = ~chords;
	~chords = Pseries(21, ~xIntervals, ~model.dim).collect { |bass|
		Pseries(bass, ~yIntervals, ~model.dim).asStream.all
	}.asStream.all;
	// not convinced... maybe blend with long tones
	~blend = Plazy({ Env(#[0, 1], [rrand(0.4, 0.8)]) });
};

BP(\st).chords.do(_.postln); ""

BP(\st).listVars

BP(\st).event[\midiNoteToFreq] = _.midicps;

BP(\st).event[\midiNoteToFreq].def.dumpByteCodes

BP(\st).mod_lev = Pfunc({ ~model.centroid.y.linlin(-1, 1, 6.0, 0.3) });



// arpeggiator; reset pattern on "wipe" gesture (or any fast motion)
// use streamtrack to have multiple layers at once
(
BP(\arp).free;

PR(\streamTrack).chuck(BP(\arp), nil, (
	// set ~model at chuck time
	event: (eventKey: \voicerNote),
	alwaysReset: true,

	prep: {
	},

	preparePlay: {
		~changeChordModeStream ?? { ~makeStreamForKey.(\changeChordMode) };
		~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
	},
	userStop: { ~resp.remove },

	xIntervals: Pwhite(3, 6, inf),
	yIntervals: Pwhite(1, 4, inf),
	changeChordMode: \patRejectLastN.eval(Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf), 6),

	changeChords: { |inevent|
		// ~oldMode = ~mode;
		~mode = ~changeChordModeStream.next(inevent);
		// ~oldChords = ~chords;
		~chords = Pseries(21, ~xIntervals, ~model.dim).collect { |bass|
			Pseries(bass, ~yIntervals, ~model.dim).asStream.all
		}.asStream.all;
		// not convinced... maybe blend with long tones
		~blend = Plazy({ Env(#[0, 1], [rrand(0.4, 0.8)]) });
	},

	asPattern: {
	}
));
)