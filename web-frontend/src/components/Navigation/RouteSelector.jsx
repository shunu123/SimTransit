import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { MapPin, Search, Navigation2, ArrowRight, ArrowLeft, History, Map as MapIcon } from 'lucide-react';
import { getSearchSuggestions } from '../../services/api';

const RouteSelector = ({ onSearch, initialFrom = '', initialTo = '' }) => {
    const [step, setStep] = useState('from'); // from, to
    const [from, setFrom] = useState(initialFrom);
    const [to, setTo] = useState(initialTo);
    const [suggestions, setSuggestions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [history] = useState([
        { from: 'Main Gate', to: 'Campus Library' },
        { from: 'North Hostel', to: 'Sports Complex' }
    ]);

    const fetchSuggestions = useCallback(async (query) => {
        if (!query || query.length < 2) {
            setSuggestions([]);
            return;
        }
        setLoading(true);
        try {
            const res = await getSearchSuggestions(query);
            if (res.ok) setSuggestions(res.data || []);
        } catch (err) {
            console.error("Search suggestion error:", err);
        } finally {
            setLoading(false);
        }
    }, []);

    // Debounce for search
    useEffect(() => {
        const timeout = setTimeout(() => {
            fetchSuggestions(step === 'from' ? from : to);
        }, 300);
        return () => clearTimeout(timeout);
    }, [from, to, step, fetchSuggestions]);

    const handleSelect = (stopName) => {
        if (step === 'from') {
            setFrom(stopName);
            setStep('to');
        } else {
            setTo(stopName);
            onSearch(from, stopName);
        }
    };

    const containerVariants = {
        hidden: { opacity: 0, x: 20 },
        visible: { opacity: 1, x: 0, transition: { duration: 0.4, ease: [0.4, 0, 0.2, 1] } },
        exit: { opacity: 0, x: -20, transition: { duration: 0.3 } }
    };

    return (
        <div className="flex-1 flex flex-col bg-black overflow-hidden h-full">
            {/* PROGRESS INDICATOR */}
            <div className="flex items-center gap-1 p-8 pb-4">
                <div className={`h-1 flex-1 rounded-full transition-all duration-500 ${step === 'from' ? 'bg-[var(--accent)]' : 'bg-[var(--accent)]/40'}`} />
                <div className={`h-1 flex-1 rounded-full transition-all duration-500 ${step === 'to' ? 'bg-[var(--accent)]' : 'bg-white/10'}`} />
            </div>

            <AnimatePresence mode="wait">
                <motion.div 
                    key={step}
                    variants={containerVariants}
                    initial="hidden"
                    animate="visible"
                    exit="exit"
                    className="flex-1 flex flex-col p-8 pt-0 h-full min-h-0"
                >
                    <div className="flex flex-col gap-1 mb-6">
                        <div className="flex items-center gap-3 mb-2">
                            {step === 'to' && (
                                <button 
                                    onClick={() => setStep('from')}
                                    className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/40 hover:text-white transition-all shadow-lg"
                                >
                                    <ArrowLeft size={18} />
                                </button>
                            )}
                            <span className="text-[10px] font-black text-[var(--accent)] uppercase tracking-[0.4em]">Step {step === 'from' ? '01' : '02'}</span>
                        </div>
                        <h2 className="text-4xl font-black text-white tracking-tighter leading-none">
                            {step === 'from' ? 'From' : 'To'}
                        </h2>
                        <p className="text-[11px] font-bold text-white/30 uppercase tracking-[0.2em] leading-relaxed">Where {step === 'from' ? 'are we starting?' : 'is the end goal?'}</p>
                    </div>

                    {/* SEARCH INPUT */}
                    <div className="relative group mb-6 shrink-0">
                        <div className="absolute inset-x-0 bottom-0 h-[1px] bg-white/10 group-focus-within:bg-[var(--accent)] transition-all" />
                        <div className="flex items-center gap-4 py-4 px-2">
                            <Search className="text-white/20 group-focus-within:text-[var(--accent)] transition-all" size={20} />
                            <input 
                                autoFocus
                                value={step === 'from' ? from : to}
                                onChange={(e) => step === 'from' ? setFrom(e.target.value) : setTo(e.target.value)}
                                placeholder={step === 'from' ? "Pick a starting stop..." : "Pick a destination..."}
                                className="bg-transparent border-none outline-none text-white font-bold text-xl placeholder:text-white/10 w-full tracking-tight"
                            />
                        </div>
                    </div>

                    {/* SUGGESTIONS / HISTORY */}
                    <div className="flex-1 overflow-y-auto scrollbar-hide space-y-3 min-h-0">
                        {suggestions.length > 0 ? (
                            suggestions.map((s, i) => (
                                <motion.button
                                    key={i}
                                    whileHover={{ x: 4 }}
                                    onClick={() => handleSelect(s.name)}
                                    className="w-full flex items-center justify-between p-5 bg-white/5 border border-white/5 rounded-[28px] hover:bg-white/10 transition-all text-left group shadow-lg"
                                >
                                    <div className="flex items-center gap-4">
                                        <div className="w-10 h-10 rounded-2xl bg-white/5 flex items-center justify-center text-[var(--accent)] group-hover:bg-[var(--accent)] group-hover:text-white transition-all">
                                            <MapPin size={18} />
                                        </div>
                                        <div className="flex flex-col">
                                            <span className="text-sm font-black text-white">{s.name}</span>
                                            <span className="text-[9px] font-bold text-white/20 uppercase tracking-widest">{s.type || 'Bus Stop'}</span>
                                        </div>
                                    </div>
                                    <ArrowRight size={16} className="text-white/10 group-hover:text-white transition-all" />
                                </motion.button>
                            ))
                        ) : (from === '' && step === 'from') || (to === '' && step === 'to') ? (
                            <div className="space-y-8 py-4">
                                <div className="px-2">
                                    <h4 className="text-[10px] font-black text-white/20 uppercase tracking-[0.4em] mb-4">Quick Shortcuts</h4>
                                    <div className="space-y-1">
                                        {history.map((h, i) => (
                                            <button 
                                                key={i}
                                                onClick={() => {
                                                    setFrom(h.from);
                                                    setTo(h.to);
                                                    onSearch(h.from, h.to);
                                                }}
                                                className="w-full flex items-center gap-4 p-4 hover:bg-white/5 rounded-2xl transition-all group"
                                            >
                                                <History size={14} className="text-white/20 group-hover:text-[var(--accent)]" />
                                                <span className="text-[11px] font-bold text-white/30 uppercase tracking-widest group-hover:text-white transition-all">{h.from} → {h.to}</span>
                                            </button>
                                        ))}
                                    </div>
                                </div>
                                
                                <div className="p-8 border border-dashed border-white/5 rounded-[32px] flex flex-col items-center gap-4 text-center opacity-40">
                                    <MapIcon size={32} className="text-white/20" />
                                    <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest leading-relaxed max-w-[200px]">Interactive map selection coming soon...</p>
                                </div>
                            </div>
                        ) : null}
                    </div>

                    {/* ACTION BUTTON (CONFIRM) */}
                    <div className="mt-auto pt-6 bg-black">
                        {(step === 'from' && from) || (step === 'to' && to) ? (
                            <button 
                                onClick={() => handleSelect(step === 'from' ? from : to)}
                                className="w-full h-[64px] bg-white text-black rounded-[24px] font-black text-[11px] uppercase tracking-[0.3em] flex items-center justify-center gap-3 hover:bg-[var(--accent)] hover:text-white transition-all shadow-2xl active:scale-95"
                            >
                                {step === 'from' ? 'Confirm Start' : 'Launch Search'}
                                <ArrowRight size={18} />
                            </button>
                        ) : (
                            <button 
                                onClick={() => {/* GPS functionality here */}}
                                className="w-full h-[64px] bg-white/5 text-white/40 border border-white/10 rounded-[24px] font-black text-[11px] uppercase tracking-[0.3em] flex items-center justify-center gap-3 hover:bg-white/10 hover:text-white transition-all active:scale-95"
                            >
                                <Navigation2 size={18} />
                                Locate Me
                            </button>
                        )}
                    </div>
                </motion.div>
            </AnimatePresence>
        </div>
    );
};

export default RouteSelector;
