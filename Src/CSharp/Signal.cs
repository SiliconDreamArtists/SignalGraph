//------------------------------------------------------------------------------
// <copyright file="Signal.cs" company="Silicon Dream Artists">
//     Copyright (c) Silicon Dream Artists. All rights reserved.
// </copyright>
//------------------------------------------------------------------------------

namespace SignalGraph
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Runtime.Serialization;
    using Microsoft.Extensions.Logging;
    using Newtonsoft.Json;

    [DataContract]
    public partial class    Signal : ILogger, ISignal
    {
        private const SignalFeedbackLevel FailureLevel = SignalFeedbackLevel.Critical;

        private const SignalFeedbackLevel SuccessLevel = SignalFeedbackLevel.Retry;

        private static ILogger logger;

        private List<SignalFeedbackEntry> entries;

        public Signal()
        {
        }

        public Signal(params Signal[] priorSignals)
        {
            this.MergeSignal(priorSignals);
        }

        public static bool HasLogger => logger != null;


        public static ILogger Logger
        {
            get
            {
                if (!HasLogger)
                {
                    throw new Exception("Logger must be initialized.");
                }

                return logger;
            }

            set
            {
                logger = value;
            }
        }

        [DataMember]
        public SignalFeedbackLevel Level { get; set; }

        [DataMember]
        public string LevelName => this.Level.ToString();

        [DataMember]
        public List<SignalFeedbackEntry> Entries
        {
            get
            {
                this.entries = this.entries ?? new List<SignalFeedbackEntry>();
                return this.entries;
            }

            set
            {
                this.entries = value;
            }
        }

        public IEnumerable<string> EntryMessages => this.GetFeedbackEntries(SignalFeedbackLevel.Unspecified);

        public IEnumerable<string> CriticalEntryMessages => this.GetFeedbackEntries(SignalFeedbackLevel.Critical);

        public IEnumerable<SignalFeedbackEntry> CriticalEntries => this.Entries.ToList().Where(x => x.Level == SignalFeedbackLevel.Critical);

        [DataMember]
        public string CriticalSummary => string.Join(",", this.Entries.ToList().Where(x => x.Level >= SignalFeedbackLevel.Critical).Select(x => x.Message));

        public bool Failure => this.CheckForLevelFailure();

        public bool Success => this.CheckForLevelSuccess();

        public static Signal Start(Signal importExecutionResults = null)
        {
            return new Signal(importExecutionResults);
        }

        public static Signal Start(SignalFeedbackLevel signalLevel, string message, Exception ex = null, params Signal[] priorExecutionResults)
        {
            Signal result = new Signal(priorExecutionResults);
            result.LogMessage(signalLevel, message, ex);
            return result;
        }

        public static Signal<T> Start<T>(T defaultResult = default, params Signal[] priorExecutionResults)
        {
            Signal<T> result = new Signal<T>(defaultResult, priorExecutionResults);
            return result;
        }

        public static Signal<T> Start<T>(T defaultResult, SignalFeedbackLevel signalLevel, string logMessage, params Signal[] priorExecutionResults)
        {
            return Start<T>(defaultResult, signalLevel, null, logMessage, priorExecutionResults);
        }

        public static Signal<T> Start<T>(T defaultResult, SignalFeedbackLevel signalLevel, Exception ex, string logMessage, params Signal[] priorExecutionResults)
        {
            Signal<T> result = new Signal<T>(defaultResult, priorExecutionResults);
            result.LogMessage(signalLevel, logMessage, ex);
            return result;
        }

        public void CreateFeedbackEntry(SignalFeedbackLevel severity, string message, Exception exception = null)
        {
            switch (severity)
            {
                case SignalFeedbackLevel.Information:
                    {
                        Logger.LogInformation(message);
                    }

                    break;

                case SignalFeedbackLevel.Warning:
                    {
                        Logger.LogWarning(message);
                    }

                    break;


                case SignalFeedbackLevel.Retry:
                    {
                        Logger.LogWarning("Retry: " + message);
                    }

                    break;

                case SignalFeedbackLevel.Critical:
                    {
                        Logger.LogError(exception, message);
                    }

                    break;
            }
        }

        public IEnumerable<string> GetFeedbackEntries(SignalFeedbackLevel minimumSeverityToGet)
        {
            this.entries = this.entries ?? new List<SignalFeedbackEntry>();
            return this.entries.ToList().Where(x => x.Level >= minimumSeverityToGet).Select(x => $"<{x.Level}>{x.Message}" + this.GetExceptionMessage(x.Exception));
        }

        public string GetExceptionMessage(Exception ex)
        {
            if (ex == null)
            {
                return string.Empty;
            }

            return $" - {ex.Message}";
        }

        public bool MergeSignalAndCheckForFail(params Signal[] mergeSignal)
        {
            this.MergeSignal(mergeSignal);
            return this.Failure;
        }

        public bool MergeSignalAndVerifySuccess(params Signal[] mergeSignal)
        {
            this.MergeSignal(mergeSignal);
            return this.Success;
        }

        public Signal MergeSignal(params Signal[] mergeSignal)
        {
            foreach (Signal priorExecutionResult in mergeSignal.ToList())
            {
                if (priorExecutionResult?.entries != null && priorExecutionResult.entries.Count > 0)
                {
                    this.Entries.AddRange(priorExecutionResult.entries);
                    this.SetFeedbackLevel();
                }
            }

            return this;
        }

        public SignalFeedbackEntry LogInformation(string message, Exception exception = null)
        {
            return this.LogMessage(SignalFeedbackLevel.Information, message, exception);
        }

        public SignalFeedbackEntry LogWarning(string message, Exception exception = null)
        {
            return this.LogMessage(SignalFeedbackLevel.Warning, message, exception);
        }

        public SignalFeedbackEntry LogRetry(string message, Exception exception = null)
        {
            return this.LogMessage(SignalFeedbackLevel.Retry, message, exception);
        }

        public SignalFeedbackEntry LogVerbose(string message, Exception exception = null)
        {
            return this.LogMessage(SignalFeedbackLevel.VerboseInformation, message, exception);
        }

        public SignalFeedbackEntry LogCritical(string message, Exception exception = null)
        {
            return this.LogMessage(SignalFeedbackLevel.Critical, message, exception);
        }

        public SignalFeedbackEntry LogMessage(SignalFeedbackLevel severity, string message, Exception exception = null)
        {
            var newMessage = new SignalFeedbackEntry(severity, message, exception);
            this.Entries.Add(newMessage);
            this.CreateFeedbackEntry(severity, message, exception);
            this.SetFeedbackLevel(severity);
            return newMessage;
        }

        public SignalFeedbackLevel SetFeedbackLevel()
        {
            if (this.entries == null || this.entries.Count == 0)
            {
                this.Level = SignalFeedbackLevel.Information;
            }
            else
            {
                var maxLevel = this.Entries.ToList()?.Max(x => x.Level);
                this.Level = maxLevel ?? SignalFeedbackLevel.Information;
            }

            return this.Level;
        }

        public SignalFeedbackLevel SetFeedbackLevel(SignalFeedbackLevel signalLevel)
        {
            this.Level = signalLevel > this.Level ? signalLevel : this.Level;
            return this.Level;
        }

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception exception, Func<TState, Exception, string> formatter)
        {
            if (this.IsEnabled(logLevel))
            {
                switch (logLevel)
                {
                    case LogLevel.Information:
                        {
                            Logger.LogInformation(formatter.Invoke(state, exception));
                        }

                        break;

                    case LogLevel.Warning:
                        {
                            Logger.LogWarning(formatter.Invoke(state, exception));
                        }

                        break;

                    case LogLevel.Critical:
                        {
                            Logger.LogError(exception, formatter.Invoke(state, exception));
                        }

                        break;
                }
            }
        }

        public bool IsEnabled(LogLevel logLevel)
        {
            return true;
        }

        public IDisposable BeginScope<TState>(TState state)
        {
            throw new NotImplementedException();
        }

        public bool CheckForLevelFailure(bool allowEquals = false, SignalFeedbackLevel passingSeverity = SuccessLevel)
        {
            return this.Level > passingSeverity || (allowEquals && this.Level == passingSeverity);
        }

        public bool CheckForLevelSuccess(bool allowEquals = true, SignalFeedbackLevel passingSeverity = SuccessLevel)
        {
            return this.Level < passingSeverity || (allowEquals && this.Level == passingSeverity);
        }

        public string ToJson()
        {
            return JsonConvert.SerializeObject(this);
        }
        public static Signal FromJson(string json) => JsonConvert.DeserializeObject<Signal>(json);
    }
}
