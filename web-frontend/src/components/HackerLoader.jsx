import React, { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const HackerLoader = ({ isVisible = true }) => {
    const canvasRef = useRef(null);
    const [messageIndex, setMessageIndex] = useState(0);

    const messages = [
        "INITIALIZING BYPASS...",
        "ACCESSING SATELLITE UPLINK...",
        "DECRYPTING TRAFFIC DATA...",
        "SYNCHRONIZING FLEET CLOUD...",
        "BYPASSING SECURITY FIREWALL...",
        "ESTABLISHING SECURE CONNECTION...",
        "MAPPING TRANSIT NODES...",
        "INJECTING ROUTE LOGIC..."
    ];

    useEffect(() => {
        if (!isVisible) return;

        const interval = setInterval(() => {
            setMessageIndex(prev => (prev + 1) % messages.length);
        }, 1500);

        return () => clearInterval(interval);
    }, [isVisible, messages.length]);

    useEffect(() => {
        if (!isVisible) return;

        const canvas = canvasRef.current;
        const ctx = canvas.getContext('2d');

        let width = canvas.width = window.innerWidth;
        let height = canvas.height = window.innerHeight;

        const columns = Math.floor(width / 20);
        const drops = Array(columns).fill(0);

        const draw = () => {
            ctx.fillStyle = 'rgba(0, 0, 0, 0.1)';
            ctx.fillRect(0, 0, width, height);

            ctx.fillStyle = '#10b981'; // emerald-500
            ctx.font = 'bold 15px monospace';

            for (let i = 0; i < drops.length; i++) {
                const text = Math.random() > 0.5 ? '1' : '0';
                const x = i * 20;
                const y = drops[i] * 20;

                // Add slight glow
                ctx.shadowBlur = 8;
                ctx.shadowColor = '#10b981';
                
                ctx.fillText(text, x, y);
                ctx.shadowBlur = 0;

                if (y > height && Math.random() > 0.975) {
                    drops[i] = 0;
                }
                drops[i]++;
            }
        };

        let animationFrameId;
        const render = () => {
            draw();
            animationFrameId = requestAnimationFrame(render);
        };
        render();

        const handleResize = () => {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
            // Recalculate drops if needed, but simple resize is fine
        };

        window.addEventListener('resize', handleResize);

        return () => {
            cancelAnimationFrame(animationFrameId);
            window.removeEventListener('resize', handleResize);
        };
    }, [isVisible]);

    return (
        <AnimatePresence>
            {isVisible && (
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.4 }}
                    style={{
                        position: 'fixed',
                        inset: 0,
                        zIndex: 9999,
                        backgroundColor: '#000',
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'center',
                        justifyContent: 'center',
                        overflow: 'hidden'
                    }}
                >
                    <canvas
                        ref={canvasRef}
                        style={{
                            position: 'absolute',
                            inset: 0,
                            opacity: 0.4
                        }}
                    />
                    
                    <div style={{ position: 'relative', zIndex: 1, textAlign: 'center' }}>
                        <motion.div
                            animate={{ 
                                scale: [1, 1.05, 1],
                                opacity: [0.8, 1, 0.8]
                            }}
                            transition={{ 
                                duration: 2,
                                repeat: Infinity,
                                ease: "easeInOut"
                            }}
                            style={{
                                width: '120px',
                                height: '120px',
                                border: '2px solid #10b981',
                                borderRadius: '50%',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                marginBottom: '2rem',
                                boxShadow: '0 0 30px rgba(16, 185, 129, 0.3), inset 0 0 20px rgba(16, 185, 129, 0.2)'
                            }}
                        >
                            <div style={{
                                width: '80px',
                                height: '80px',
                                border: '4px solid #10b981',
                                borderTopColor: 'transparent',
                                borderRadius: '50%',
                                animation: 'spin 1s linear infinite'
                            }} />
                            <div style={{
                                position: 'absolute',
                                color: '#10b981',
                                fontWeight: 'bold',
                                fontSize: '0.7rem',
                                letterSpacing: '2px'
                            }}>
                                ROOT
                            </div>
                        </motion.div>

                        <div style={{
                            backgroundColor: 'rgba(16, 185, 129, 0.1)',
                            border: '1px solid rgba(16, 185, 129, 0.3)',
                            padding: '1rem 2rem',
                            borderRadius: '12px',
                            backdropFilter: 'blur(10px)',
                            minWidth: '300px'
                        }}>
                            <motion.div
                                key={messageIndex}
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -10 }}
                                style={{
                                    color: '#10b981',
                                    fontFamily: 'monospace',
                                    fontSize: '0.8rem',
                                    fontWeight: 'bold',
                                    letterSpacing: '3px',
                                    textShadow: '0 0 10px rgba(16, 185, 129, 0.5)'
                                }}
                            >
                                {messages[messageIndex]}
                            </motion.div>
                            
                            <div style={{
                                height: '2px',
                                width: '100%',
                                backgroundColor: 'rgba(16, 185, 129, 0.1)',
                                marginTop: '1rem',
                                borderRadius: '1px',
                                overflow: 'hidden'
                            }}>
                                <motion.div
                                    animate={{ 
                                        x: ['-100%', '100%']
                                    }}
                                    transition={{ 
                                        duration: 1.5,
                                        repeat: Infinity,
                                        ease: "linear"
                                    }}
                                    style={{
                                        height: '100%',
                                        width: '40%',
                                        backgroundColor: '#10b981',
                                        boxShadow: '0 0 10px #10b981'
                                    }}
                                />
                            </div>
                        </div>

                        <div style={{
                            marginTop: '1.5rem',
                            color: 'rgba(16, 185, 129, 0.4)',
                            fontFamily: 'monospace',
                            fontSize: '0.6rem',
                            letterSpacing: '5px',
                            textTransform: 'uppercase'
                        }}>
                            Unauthorized access detected
                        </div>
                    </div>

                    <style>
                        {`
                            @keyframes spin {
                                from { transform: rotate(0deg); }
                                to { transform: rotate(360deg); }
                            }
                        `}
                    </style>
                </motion.div>
            )}
        </AnimatePresence>
    );
};

export default HackerLoader;
