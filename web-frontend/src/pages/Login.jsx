import React, { useState, useRef } from 'react';
import MapBackground from '../components/MapBackground';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../context/AuthContext';
import { loginUser, sendOtp, verifyOtp } from '../services/api';
import HackerLoader from '../components/HackerLoader';

const ACCENT = '#f59e0b'; // gold

const Login = () => {
    const [step, setStep] = useState('credentials'); // 'credentials' | 'otp' | 'forgot'
    const [regNoOrEmail, setRegNoOrEmail] = useState('');
    const [password, setPassword] = useState('');
    const [adminEmail, setAdminEmail] = useState('');
    const [forgotEmail, setForgotEmail] = useState('');
    const [forgotSent, setForgotSent] = useState(false);
    const [otp, setOtp] = useState(['', '', '', '']);
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const otpRefs = [useRef(), useRef(), useRef(), useRef()];
    const { login } = useAuth();
    const navigate = useNavigate();
    const borderColor = ACCENT;

    const handleLogin = async (e) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);
        try {
            const data = await loginUser(regNoOrEmail, password);
            if (data.requires_otp && data.target) {
                setAdminEmail(data.target);
                setStep('otp');
            } else {
                login(data);
                navigate('/dashboard');
            }
        } catch (err) {
            setError(typeof err === 'string' ? err : 'Invalid credentials.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleOtpChange = (idx, val) => {
        if (!/^\d?$/.test(val)) return;
        const next = [...otp];
        next[idx] = val;
        setOtp(next);
        if (val && idx < 3) otpRefs[idx + 1].current?.focus();
        if (!val && idx > 0) otpRefs[idx - 1].current?.focus();
    };

    const handleOtpPaste = (e) => {
        const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 4);
        if (pasted.length === 4) {
            setOtp(pasted.split(''));
            otpRefs[3].current?.focus();
        }
    };

    const handleVerifyOtp = async (e) => {
        e.preventDefault();
        setError('');
        const code = otp.join('');
        if (code.length < 4) { setError('Enter the 4-digit OTP.'); return; }
        setIsLoading(true);
        try {
            const data = await verifyOtp(adminEmail, code, false, true);
            if (data.ok && data.user) {
                login(data);
                navigate('/dashboard');
            } else {
                setError('Verification failed. Please try again.');
            }
        } catch (err) {
            setError(typeof err === 'string' ? err : 'Invalid or expired OTP.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleResendOtp = async () => {
        setError('');
        try { await sendOtp(adminEmail, false); }
        catch (err) { setError('Failed to resend OTP.'); }
    };

    const handleForgotPassword = async (e) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);
        try {
            // Send OTP to the provided email for reset
            await sendOtp(forgotEmail, false);
            setForgotSent(true);
        } catch (err) {
            setError('Could not send reset link. Check your email/ID.');
        } finally {
            setIsLoading(false);
        }
    };

    // Animated glass card wrapper
    const CardWrapper = ({ children, motionKey }) => (
        <motion.div
            key={motionKey}
            initial={{ opacity: 0, y: 15, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -10, scale: 0.98 }}
            transition={{ duration: 0.45, ease: [0.25, 0.46, 0.45, 0.94] }}
            style={{
                width: '100%',
                maxWidth: '420px',
                padding: '3px',          /* border thickness */
                borderRadius: '22px',
                background: `linear-gradient(135deg, ${borderColor}, rgba(255,255,255,0.05) 50%, ${borderColor})`,
                boxShadow: `0 0 40px ${borderColor}33, 0 30px 60px rgba(0,0,0,0.6)`,
                transition: 'background 0.8s ease, box-shadow 0.8s ease',
            }}
        >
            <div style={{
                background: 'rgba(8,8,8,0.88)',
                backdropFilter: 'blur(40px)',
                WebkitBackdropFilter: 'blur(40px)',
                borderRadius: '20px',
                padding: '2.75rem 2.25rem',
            }}>
                {children}
            </div>
        </motion.div>
    );

    return (
        <div className="map-page">
            <MapBackground />
            <div className="map-overlay" />
            <div className="map-content">
                <AnimatePresence mode="wait">

                    {/* ─── CREDENTIALS STEP ─── */}
                    {step === 'credentials' && (
                        <CardWrapper motionKey="credentials">
                            <div style={s.header}>
                                <h2 style={s.title}>Sign In</h2>
                                <p style={s.sub}>Access your transit dashboard</p>
                            </div>
                            {error && <div style={s.errorBadge}>{error}</div>}
                            <form style={s.form} onSubmit={handleLogin}>
                                <div style={s.group}>
                                    <label className="form-label">Registration Number or Email</label>
                                    <input
                                        type="text"
                                        className="form-input"
                                        placeholder="e.g. 21BCE0000 or ADMIN001"
                                        value={regNoOrEmail}
                                        onChange={(e) => setRegNoOrEmail(e.target.value)}
                                        required
                                    />
                                </div>
                                <div style={s.group}>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <label className="form-label" style={{ marginBottom: 0 }}>Password</label>
                                        <button
                                            type="button"
                                            onClick={() => { setStep('forgot'); setError(''); setForgotSent(false); }}
                                            style={{ background: 'none', border: 'none', color: borderColor, fontSize: '0.78rem', fontWeight: 700, cursor: 'pointer', transition: 'color 0.8s ease' }}
                                        >
                                            Forgot Password?
                                        </button>
                                    </div>
                                    <input
                                        type="password"
                                        className="form-input"
                                        placeholder="Enter your password"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        required
                                    />
                                </div>
                                <button
                                    className="btn-primary"
                                    type="submit"
                                    disabled={isLoading}
                                    style={{ background: borderColor, color: '#000', transition: 'background 0.8s ease', fontWeight: 800 }}
                                >
                                    {isLoading ? 'Signing In...' : 'Sign In'}
                                </button>
                            </form>
                            <div style={s.footer}>
                                Don't have an account?{' '}
                                <Link to="/register" style={{ color: borderColor, fontWeight: 700, transition: 'color 0.8s ease' }}>Register</Link>
                            </div>
                        </CardWrapper>
                    )}

                    {/* ─── FORGOT PASSWORD STEP ─── */}
                    {step === 'forgot' && (
                        <CardWrapper motionKey="forgot">
                            <div style={s.header}>
                                <div style={{ fontSize: '2rem', marginBottom: '0.75rem' }}>🔑</div>
                                <h2 style={s.title}>Reset Password</h2>
                                <p style={s.sub}>We'll send you a reset link via email</p>
                            </div>
                            {error && <div style={s.errorBadge}>{error}</div>}
                            {forgotSent ? (
                                <div style={{ textAlign: 'center', padding: '1.5rem 0' }}>
                                    <div style={{ fontSize: '2.5rem', marginBottom: '0.75rem' }}>✅</div>
                                    <p style={{ color: '#10b981', fontWeight: 700, marginBottom: '0.5rem' }}>Reset link sent!</p>
                                    <p style={s.sub}>Check your email inbox for instructions.</p>
                                </div>
                            ) : (
                                <form style={s.form} onSubmit={handleForgotPassword}>
                                    <div style={s.group}>
                                        <label className="form-label">Email / Registration Number</label>
                                        <input
                                            type="text"
                                            className="form-input"
                                            placeholder="Enter your registered email or ID"
                                            value={forgotEmail}
                                            onChange={(e) => setForgotEmail(e.target.value)}
                                            required
                                        />
                                    </div>
                                    <button
                                        className="btn-primary"
                                        type="submit"
                                        disabled={isLoading}
                                        style={{ background: borderColor, color: '#000', transition: 'background 0.8s ease', fontWeight: 800 }}
                                    >
                                        {isLoading ? 'Sending...' : 'Send Reset Link'}
                                    </button>
                                </form>
                            )}
                            <div style={s.footer}>
                                <button
                                    onClick={() => { setStep('credentials'); setError(''); }}
                                    style={{ background: 'none', border: 'none', color: borderColor, fontWeight: 700, cursor: 'pointer', fontSize: '0.85rem', transition: 'color 0.8s ease' }}
                                >
                                    ← Back to Sign In
                                </button>
                            </div>
                        </CardWrapper>
                    )}

                    {/* ─── OTP STEP ─── */}
                    {step === 'otp' && (
                        <CardWrapper motionKey="otp">
                            <div style={s.header}>
                                <div style={{ fontSize: '2rem', marginBottom: '0.75rem' }}>🛡️</div>
                                <h2 style={s.title}>Admin Verification</h2>
                                <p style={s.sub}>
                                    OTP sent to <strong style={{ color: 'rgba(255,255,255,0.7)' }}>{adminEmail}</strong>
                                </p>
                            </div>
                            {error && <div style={s.errorBadge}>{error}</div>}
                            <form style={s.form} onSubmit={handleVerifyOtp}>
                                <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
                                    {otp.map((digit, idx) => (
                                        <input
                                            key={idx}
                                            ref={otpRefs[idx]}
                                            type="text"
                                            inputMode="numeric"
                                            maxLength={1}
                                            value={digit}
                                            onChange={(e) => handleOtpChange(idx, e.target.value)}
                                            onPaste={idx === 0 ? handleOtpPaste : undefined}
                                            style={{ ...s.otpBox, borderColor: borderColor, transition: 'border-color 0.8s ease' }}
                                            autoFocus={idx === 0}
                                        />
                                    ))}
                                </div>
                                <button
                                    className="btn-primary"
                                    type="submit"
                                    disabled={isLoading}
                                    style={{ background: borderColor, color: '#000', transition: 'background 0.8s ease', fontWeight: 800 }}
                                >
                                    {isLoading ? 'Verifying...' : 'Verify & Access'}
                                </button>
                            </form>
                            <div style={{ ...s.footer, display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                                <button onClick={handleResendOtp} style={{ background: 'none', border: 'none', color: borderColor, fontWeight: 700, cursor: 'pointer', fontSize: '0.85rem', transition: 'color 0.8s ease' }}>
                                    Resend OTP
                                </button>
                                <button onClick={() => { setStep('credentials'); setError(''); setOtp(['','','','']); }} style={{ background: 'none', border: 'none', color: 'rgba(255,255,255,0.3)', cursor: 'pointer', fontSize: '0.8rem' }}>
                                    ← Back to Login
                                </button>
                            </div>
                        </CardWrapper>
                    )}

                </AnimatePresence>
            </div>
            <HackerLoader isVisible={isLoading} />
        </div>
    );
};

const s = {
    header: { textAlign: 'center', marginBottom: '2rem' },
    title: { fontSize: '1.65rem', fontWeight: 800, color: '#ededed', letterSpacing: '-0.5px', marginBottom: '0.25rem' },
    sub: { color: 'rgba(255,255,255,0.35)', fontSize: '0.85rem' },
    form: { display: 'flex', flexDirection: 'column', gap: '1.5rem' },
    group: { display: 'flex', flexDirection: 'column', gap: '0.65rem' },
    footer: { marginTop: '1.75rem', textAlign: 'center', fontSize: '0.85rem', color: 'rgba(255,255,255,0.3)' },
    errorBadge: {
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        color: '#ef4444',
        padding: '0.75rem',
        borderRadius: '0.5rem',
        fontSize: '0.85rem',
        textAlign: 'center',
        marginBottom: '1rem',
        border: '1px solid rgba(239, 68, 68, 0.2)'
    },
    otpBox: {
        width: '56px',
        height: '64px',
        textAlign: 'center',
        fontSize: '1.5rem',
        fontWeight: 800,
        color: '#ffffff',
        background: 'rgba(255,255,255,0.05)',
        border: '2px solid',
        borderRadius: '12px',
        outline: 'none',
        caretColor: '#818cf8',
    }
};

export default Login;
