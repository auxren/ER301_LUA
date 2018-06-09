local units = {

  {category="Essentials"},
  {title="Mixer Channel",moduleName="MixerUnit",keywords="mixing, routing"},
  {title="Linear VCA",moduleName="LinearVcaUnit",keywords="modulate, utility"},
  {title="Limiter",moduleName="LimiterUnit",keywords="utility, effect, mixing"},
  {title="Offset",moduleName="OffsetUnit",keywords="utility"},

  {category="Sample Playback"},
  {title="Sample Player",moduleName="Player.PlayerUnit",keywords="sampling, source"},
  {title="Native Player",moduleName="Player.NativeSpeedPlayerUnit",keywords="sampling, source"},
  {title="Manual Grains",moduleName="Player.ManualGrains",keywords="sampling, source"},
  {title="Grain Stretch",moduleName="Player.GrainPlayer",keywords="sampling, source"},
  {title="Card Player",moduleName="File.CardPlayerUnit",keywords="source, sampling"},

  {category="Looping"},
  {title="Feedback Looper",moduleName="Looper.FeedbackLooper",keywords="sampling, effect"},
  {title="Dub Looper",moduleName="Looper.DubLooper",keywords="sampling, effect", aliases={"Looper.LooperUnit"}},
  {title="Pedal Looper",moduleName="Looper.PedalLooper",keywords="sampling, effect"},

  {category="Delays and Reverb"},
  {title="Micro Delay",moduleName="Delay.MicroDelay",keywords="delay, utility"},
  {title="Delay",moduleName="Delay.DelayUnit",keywords="delay, effect", aliases={"Delay.FixedDelayUnit"}},
  {title="Spread Delay",moduleName="Delay.SpreadDelayUnit",keywords="delay, effect", channelCount=2},
  {title="Clocked Delay",moduleName="Delay.ClockedDelayUnit",keywords="delay, effect"},
  {title="Doppler Delay",moduleName="Delay.DopplerDelayUnit",keywords="delay, effect", aliases={"Delay.VariableDelayUnit"}},
  {title="Clocked Doppler Delay",moduleName="Delay.ClockedDopplerDelay",keywords="delay, effect"},
  {title="Grain Delay",moduleName="Delay.GrainDelayUnit",keywords="delay, effect"},
  {title="Freeverb", moduleName="FreeverbUnit", keywords="effect"},

  {category="Filtering"},
  {title="Ladder LPF", moduleName="LadderFilterUnit",keywords="filter, pitch"},
  {title="Ladder HPF", moduleName="LadderHPFUnit",keywords="filter, pitch"},
  {title="EQ3",moduleName="EQ3Unit",keywords="filter, mixing"},
  {title="Fixed HPF", moduleName="FixedHPFUnit",keywords="filter, utility"},
  {title="Slew Limiter", moduleName="SlewLimiter",keywords="filter, utility"},
  {title="Exact Convolution", moduleName="ConvolutionUnit", keywords="filter, effect"},
  {title="Deadband Filter", moduleName="DeadbandFilter", keywords="filter, utility"},

  {category="Oscillators"},
  {title="Sine Osc",moduleName="SineOscillatorUnit",keywords="source, pitch, modulate"},
  {title="Aliasing Triangle",moduleName="AliasingTriangleUnit",keywords="source, pitch, modulate"},
  {title="Aliasing Saw",moduleName="AliasingSawUnit",keywords="source, pitch, modulate"},

  {category="Random"},
  {title="White Noise",moduleName="Noise.WhiteNoiseUnit",keywords="source, noise"},
  {title="Pink Noise",moduleName="Noise.PinkNoiseUnit",keywords="source, noise"},
  {title="Velvet Noise",moduleName="Noise.VelvetNoiseUnit",keywords="source, noise"},

  {category="Envelopes"},
  {title="ADSR",moduleName="ADSRUnit",keywords="modulate, source, utility"},
  {title="Skewed Sine Env",moduleName="SineEnvelopeUnit",keywords="modulate, source, utility"},
  {title="Envelope Follower",moduleName="EnvelopeFollowerUnit",keywords="modulate, measure"},

  {category="Mapping and Control"},
  {title="Scale Quantizer",moduleName="Quantizer.ScaleQuantizerUnit",keywords="pitch, utility"},
  {title="Grid Quantizer",moduleName="Quantizer.GridQuantizerUnit",keywords="effect",aliases={"QuantizerUnit"}},
  {title="Sample & Hold",moduleName="SampleHoldUnit",keywords="utility, effect, modulate"},
  {title="Track & Hold",moduleName="TrackHoldUnit",keywords="utility, effect, modulate"},
  {title="Bump Scanner",moduleName="BumpMap",keywords="utility, effect"},
  {title="Sample Scanner",moduleName="SampleScanner",keywords="utility, effect, sampling"},
  {title="Rectify",moduleName="RectifierUnit",keywords="utility"},
  {title="Fold",moduleName="FoldUnit",keywords="effect"},
  {title="Rational VCA",moduleName="RationalVcaUnit",keywords="modulate, utility"},
  {title="Counter",moduleName="CounterUnit",keywords="utility"},

  {category="Timing"},
  {title="Clock (sec)",moduleName="timing.ClockInSeconds",keywords="source, timing"},
  {title="Clock (BPM)",moduleName="timing.ClockInBPM",keywords="source, timing"},
  {title="Clock (Hz)",moduleName="timing.ClockInHertz",keywords="source, timing"},
  {title="Quantize to Clock",moduleName="timing.QuantizeToClock",keywords="effect, timing"},
  {title="Tap Tempo",moduleName="timing.TapTempoUnit",keywords="measure, source, timing",aliases={"TapTempoUnit"}},
  {title="Pulse to Seconds",moduleName="timing.PulseToSeconds",keywords="measure, timing",aliases={"PeriodMeterUnit"}},
  {title="Pulse to Hertz",moduleName="timing.PulseToFrequency",keywords="measure, timing",aliases={"PulseToFrequency"}},

  {category="Containers"},
  {title="Custom Unit",moduleName="custom.CustomUnit",keywords="utility, effect, source, custom"},

  {category="Experimental"},
  {title="Stress",moduleName="StressUnit",keywords="debug"},
  --{title="Countdown",moduleName="research.Countdown",keywords="timing"},

}

return {
  title = "Builtin Units",
  name = "builtins",
  keyword = "builtin",
  units = units
}
