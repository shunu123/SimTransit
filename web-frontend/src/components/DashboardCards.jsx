import React from 'react';
import { motion } from 'framer-motion';
import { Search, MapPin, Bus, ArrowRight, Loader2, ArrowUpDown, Navigation2, Activity } from 'lucide-react';

const containerVariants = {
    initial: { opacity: 0 },
    animate: {
        opacity: 1,
        transition: {
            staggerChildren: 0.15,
            delayChildren: 0.2
        }
    }
};

const cardVariants = {
    initial: { opacity: 0, y: 30, scale: 0.95 },
    animate: {
        opacity: 1,
        y: 0,
        scale: 1,
        transition: {
            duration: 0.8,
            ease: [0.16, 1, 0.3, 1]
        }
    }
};

const DashboardCard = ({ title, subtitle, icon: Icon, iconBg, children, ctaLabel, onCtaClick, loading }) => {
    // Map existing iconBg strings to neon gradient combinations
    const getGradients = (bgClass) => {
        if (bgClass.includes('3B5BDB')) return { grad: 'from-[#1e3a8a] to-[#3b82f6]', glow: 'shadow-[#1e3a8a]/40' };
        if (bgClass.includes('12B886')) return { grad: 'from-[#065f46] to-[#10b981]', glow: 'shadow-[#065f46]/40' };
        if (bgClass.includes('F76707')) return { grad: 'from-[#9a3412] to-[#f97316]', glow: 'shadow-[#9a3412]/40' };
        return { grad: 'from-gray-600 to-gray-400', glow: 'shadow-white/20' };
    };

    const { grad } = getGradients(iconBg);

    return (
        <div className="flex-1 lg:min-w-[360px] lg:max-w-[400px] rounded-[24px] bg-white/[0.04] backdrop-blur-3xl border-2 border-white/10 flex flex-col box-border shadow-[0_32px_64px_-16px_rgba(0,0,0,0.6)] relative group overflow-hidden">
            {/* GLOW ACCENT */}
            <div className="absolute top-0 left-0 w-full h-full bg-gradient-to-br from-white/[0.03] to-transparent pointer-events-none" />
            <div className={`absolute -top-20 -right-20 w-40 h-40 bg-gradient-to-br ${grad} opacity-[0.03] blur-[80px] rounded-full pointer-events-none`} />

            {/* MAIN CONTENT AREA (Padded) */}
            <div className="p-[40px] pb-0 flex-1 flex flex-col">
                {/* ICON & HEADER HOOK */}
                <div className="flex items-center gap-4 mb-10">
                    <div className="relative shrink-0 w-[56px] h-[56px]">
                        <div className={`absolute inset-0 rounded-full bg-gradient-to-br ${grad} opacity-20 blur-lg`} />
                        <div className={`w-full h-full rounded-full bg-gradient-to-br ${grad} flex items-center justify-center border-2 border-white/20 relative z-10 shadow-inner`}>
                            <Icon size={24} className="text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.4)]" />
                        </div>
                    </div>
                    <div>
                        <h3 className="text-[22px] font-black text-white leading-tight tracking-tight">{title}</h3>
                        <p className="text-white/80 text-[10px] font-black uppercase tracking-[0.2em] mt-0.5">{subtitle}</p>
                    </div>
                </div>

                {/* DYNAMIC CONTENT */}
                <div className="flex-1 space-y-6">
                    {children}
                </div>
            </div>

            {/* DISTINCT ACTION BAR (Footer) */}
            <div className="p-6 mt-12 bg-white/[0.02] border-t-2 border-white/[0.06]">
                <button
                    onClick={onCtaClick}
                    disabled={loading}
                    className="w-full h-[52px] flex items-center justify-center gap-3 text-white font-black text-[12px] uppercase tracking-[0.2em] rounded-xl bg-white/[0.05] border-2 border-white/10 hover:border-white/20 hover:bg-white/[0.08] transition-all duration-300 shadow-lg group"
                >
                    {loading ? <Loader2 className="animate-spin" size={18} /> : (
                        <>
                            <span>{ctaLabel}</span>
                            <ArrowRight size={18} className="translate-y-[-1px] opacity-40 group-hover:opacity-100 transition-opacity" />
                        </>
                    )}
                </button>
            </div>
        </div>
    );
};

// Premium Compact Input Component (Icon outside)
const PremiumInput = ({ value, placeholder, icon: InputIcon, onChange, onFocus, children }) => (
    <div className="flex items-center gap-5 group/input w-full relative">
        <div className="text-white/30 group-focus-within/input:text-white transition-colors shrink-0">
            <InputIcon size={20} />
        </div>
        <div className="flex-1 relative">
            <input
                type="text"
                value={value}
                placeholder={placeholder}
                onFocus={onFocus}
                onChange={onChange}
                className="w-full h-[52px] bg-black/40 border-2 border-white/[0.08] rounded-xl pl-10 pr-6 text-white placeholder:text-white/25 text-[14px] font-bold outline-none transition-all focus:border-white/20 focus:bg-white/[0.04] shadow-inner"
            />
            {children}
        </div>
    </div>
);

const DashboardCards = ({
    onFindBus,
    onNearbyStops,
    onTrackBus,
    sourceQuery,
    setSourceQuery,
    destQuery,
    setDestQuery,
    busNumber,
    setBusNumber,
    loading,
    activeSuggestionsField,
    setActiveSuggestionsField,
    suggestions = [],
    onSuggestionClick,
    user,
    onFleetView
}) => {
    const isAdmin = user?.role === 'admin' || user?.is_admin === true || user?.user_type === 'admin';
    return (
        <div className="w-full flex flex-wrap lg:flex-nowrap justify-center gap-[40px] box-border max-w-full pb-20 items-stretch">
            {/* CARD 1: FIND BUS */}
            <DashboardCard
                title="Find Bus"
                subtitle="EXPLORE ROUTES"
                icon={Search}
                iconBg="bg-[#3B5BDB]"
                ctaLabel="Search Now"
                onCtaClick={onFindBus}
                loading={loading}
            >
                <div className="flex flex-col gap-8 relative">
                    <PremiumInput 
                        icon={MapPin}
                        placeholder="Departure Station"
                        value={sourceQuery}
                        onFocus={() => setActiveSuggestionsField('source')}
                        onChange={(e) => setSourceQuery(e.target.value)}
                    >
                        {activeSuggestionsField === 'source' && sourceQuery.length >= 2 && (
                            <div className="absolute top-[calc(100%+8px)] left-0 right-0 bg-[#1A1A1A] border-2 border-white/10 rounded-xl shadow-2xl z-[5000] overflow-hidden">
                                {suggestions.length > 0 ? (
                                    suggestions.map((s, i) => (
                                        <button 
                                            key={i}
                                            onClick={() => onSuggestionClick('source', s)}
                                            className="w-full text-left px-5 py-3 text-white hover:bg-white/5 transition-colors text-xs font-bold"
                                        >
                                            {s.name || s.stop_name || s}
                                        </button>
                                    ))
                                ) : (
                                    <div className="px-5 py-4 text-white/40 text-[10px] font-black uppercase tracking-widest text-center">
                                        No results found
                                    </div>
                                )}
                            </div>
                        )}
                    </PremiumInput>

                    <PremiumInput 
                        icon={Navigation2}
                        placeholder="Arrival Station"
                        value={destQuery}
                        onFocus={() => setActiveSuggestionsField('dest')}
                        onChange={(e) => setDestQuery(e.target.value)}
                    >
                        {/* COMPACT SWAP BUTTON */}
                        <button 
                            onClick={(e) => {
                                e.stopPropagation();
                                const temp = sourceQuery;
                                setSourceQuery(destQuery);
                                setDestQuery(temp);
                            }}
                            className="absolute right-2 top-1/2 -translate-y-1/2 w-[28px] h-[28px] rounded-lg bg-white/5 flex items-center justify-center text-white/40 hover:text-white hover:bg-white/10 transition-all z-10"
                        >
                            <ArrowUpDown size={12} />
                        </button>

                        {activeSuggestionsField === 'dest' && destQuery.length >= 2 && (
                            <div className="absolute top-[calc(100%+8px)] left-0 right-0 bg-[#1A1A1A] border-2 border-white/10 rounded-xl shadow-2xl z-[5000] overflow-hidden">
                                {suggestions.length > 0 ? (
                                    suggestions.map((s, i) => (
                                        <button 
                                            key={i}
                                            onClick={() => onSuggestionClick('dest', s)}
                                            className="w-full text-left px-5 py-3 text-white hover:bg-white/5 transition-colors text-xs font-bold"
                                        >
                                            {s.name || s.stop_name || s}
                                        </button>
                                    ))
                                ) : (
                                    <div className="px-5 py-4 text-white/40 text-[10px] font-black uppercase tracking-widest text-center">
                                        No results found
                                    </div>
                                )}
                            </div>
                        )}
                    </PremiumInput>
                </div>
            </DashboardCard>

            {/* CARD 2: NEARBY / FLEET VIEW (Role-Based) */}
            {!isAdmin ? (
                <DashboardCard
                    title="Nearby"
                    subtitle="STOPS & HUBS"
                    icon={MapPin}
                    iconBg="bg-[#12B886]"
                    ctaLabel="Find Nearby"
                    onCtaClick={onNearbyStops}
                    loading={loading}
                >
                    <div className="flex items-start gap-5 w-full">
                        <div className="text-white/30 shrink-0 mt-1">
                            <Navigation2 size={20} />
                        </div>
                        <p className="flex-1 text-white/65 text-[14px] leading-[1.6] font-medium">
                            Locating smart transit hubs and commuter nodes within a 5km precision radius of your current position.
                        </p>
                    </div>
                </DashboardCard>
            ) : (
                <DashboardCard
                    title="Fleet View"
                    subtitle="LIVE MONITOR"
                    icon={Activity}
                    iconBg="bg-[#12B886]"
                    ctaLabel="Review Fleet"
                    onCtaClick={onFleetView}
                    loading={loading}
                >
                    <div className="flex items-start gap-5 w-full">
                        <div className="text-emerald-400/50 shrink-0 mt-1">
                            <Activity size={20} />
                        </div>
                        <p className="flex-1 text-white/65 text-[14px] leading-[1.6] font-medium">
                            Real-time intelligence dashboard for active vehicles. Monitor route compliance, ETAs, and trip health.
                        </p>
                    </div>
                </DashboardCard>
            )}

            {/* CARD 3: TRACK LIVE */}
            <DashboardCard
                title="Track Live"
                subtitle="REAL-TIME"
                icon={Bus}
                iconBg="bg-[#F76707]"
                ctaLabel="Start Tracking"
                onCtaClick={onTrackBus}
                loading={loading}
            >
                <PremiumInput
                    icon={Bus}
                    placeholder="Enter Bus Number"
                    value={busNumber}
                    onChange={(e) => setBusNumber(e.target.value)}
                />
                <div className="flex items-center gap-5 w-full">
                    <div className="w-[20px] shrink-0" /> {/* Alignment Spacer */}
                    <p className="text-white/40 text-[11px] font-bold uppercase tracking-widest mt-2">
                        Visualizing active fleet positions
                    </p>
                </div>
            </DashboardCard>
        </div>
    );
};

export default DashboardCards;
