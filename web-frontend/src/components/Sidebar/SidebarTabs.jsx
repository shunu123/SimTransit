import React from 'react';
import { motion } from 'framer-motion';

const tabs = [
    { id: 'planner', label: 'Route Planner' },
    { id: 'schedule', label: 'Bus Schedule' },
    { id: 'live', label: 'Live Tracking' }
];

const SidebarTabs = ({ activeTab, onTabChange }) => {
    return (
        <div className="flex bg-white/5 p-1 rounded-[24px] border border-white/5 mb-8">
            {tabs.map((tab) => {
                const isActive = activeTab === tab.id;
                return (
                    <button
                        key={tab.id}
                        onClick={() => onTabChange(tab.id)}
                        className={`relative flex-1 py-3 text-[10px] font-black uppercase tracking-[0.1em] transition-colors duration-300 ${
                            isActive ? 'text-white' : 'text-white/30 hover:text-white/60'
                        }`}
                    >
                        {isActive && (
                            <motion.div
                                layoutId="sidebarTabBubble"
                                className="absolute inset-0 bg-white/10 rounded-[20px] shadow-lg border border-white/10"
                                transition={{ type: 'spring', bounce: 0.2, duration: 0.6 }}
                            />
                        )}
                        <span className="relative z-10">{tab.label}</span>
                    </button>
                );
            })}
        </div>
    );
};

export default SidebarTabs;
