/* ============================================================
   TASTE THE LENS — Landing Page Script
   Supabase waitlist + animations + geometric overlay
   ============================================================ */

// --- API Configuration (Edge Functions — no credentials exposed) ---
const EDGE_FUNCTION_BASE = 'https://marimaxtqnzmsynsvhrc.supabase.co/functions/v1';

// --- Waitlist Form ---
function initWaitlistForm() {
    const form = document.getElementById('waitlist-form');
    const input = document.getElementById('waitlist-email');
    const button = document.getElementById('waitlist-submit');
    const message = document.getElementById('waitlist-message');

    if (!form) return;

    let isSubmitting = false;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        if (isSubmitting) return;

        const email = input.value.trim();
        message.textContent = '';
        message.className = 'waitlist-message';
        input.classList.remove('error');

        // Client-side validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!email || !emailRegex.test(email)) {
            input.classList.add('error');
            message.textContent = 'Please enter a valid email address.';
            message.className = 'waitlist-message error';
            input.focus();
            return;
        }

        // Submit via edge function (no Supabase credentials exposed)
        isSubmitting = true;
        button.disabled = true;
        button.classList.add('loading');

        try {
            const referralSource = new URLSearchParams(window.location.search).get('ref');

            const response = await fetch(`${EDGE_FUNCTION_BASE}/waitlist-signup`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, referral_source: referralSource || null })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'Request failed');
            }

            button.classList.remove('loading');
            button.classList.add('success');

            if (data.message === 'already_registered') {
                message.textContent = "You're already on the list! We'll be in touch.";
            } else {
                message.textContent = "You're on the list! We'll notify you when we launch.";
            }
            message.className = 'waitlist-message success';
            input.value = '';

            // Reset button after 3s
            setTimeout(() => {
                button.classList.remove('success');
                button.disabled = false;
                isSubmitting = false;
            }, 3000);

        } catch (err) {
            console.error('Waitlist error:', err);
            button.classList.remove('loading');
            button.disabled = false;
            isSubmitting = false;
            message.textContent = 'Something went wrong. Please try again.';
            message.className = 'waitlist-message error';
        }
    });
}

// --- Geometric Overlay (from ProcessingAnimations.swift GeometricOverlay) ---
function initGeometricOverlay() {
    const canvas = document.getElementById('geometric-overlay');
    if (!canvas) return;

    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) {
        canvas.style.display = 'none';
        return;
    }

    const ctx = canvas.getContext('2d');
    let animationId;
    let startTime = Date.now();

    function resize() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }

    function draw() {
        const elapsed = (Date.now() - startTime) / 1000;
        // Phase cycles from 0 to 1 over 8 seconds (matching iOS: .linear(duration: 8))
        const phase = (elapsed / 8) % 1;

        ctx.clearRect(0, 0, canvas.width, canvas.height);

        const lineCount = 6;
        for (let i = 0; i < lineCount; i++) {
            const progress = i / lineCount;
            const offset = (phase + progress) % 1;

            const startX = canvas.width * offset;
            const startY = 0;
            const endX = canvas.width * (1 - offset);
            const endY = canvas.height;

            ctx.beginPath();
            ctx.moveTo(startX, startY);
            ctx.lineTo(endX, endY);
            ctx.strokeStyle = 'rgba(123, 63, 160, 0.06)'; // Purple tint matching logo palette
            ctx.lineWidth = 0.5;
            ctx.stroke();
        }

        animationId = requestAnimationFrame(draw);
    }

    resize();
    window.addEventListener('resize', resize);
    draw();

    // Cleanup on page hide
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
            cancelAnimationFrame(animationId);
        } else {
            startTime = Date.now();
            draw();
        }
    });
}

// --- Scroll Animations (IntersectionObserver) ---
function initScrollAnimations() {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) return;

    const elements = document.querySelectorAll('[data-animate]');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                const el = entry.target;
                const delay = parseInt(el.dataset.delay || '0', 10);
                setTimeout(() => {
                    el.classList.add('visible');
                }, delay);
                observer.unobserve(el);
            }
        });
    }, {
        threshold: 0.15,
        rootMargin: '0px 0px -40px 0px'
    });

    elements.forEach((el) => observer.observe(el));
}

// --- Hero Entrance Animation (from SplashView.swift timing) ---
function initHeroAnimation() {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) {
        // Show everything immediately
        document.querySelectorAll('.hero [data-animate]').forEach(el => {
            el.style.opacity = '1';
            el.style.transform = 'none';
        });
        return;
    }

    const title = document.querySelector('.hero-title');
    const tagline = document.querySelector('.hero-tagline');
    const sub = document.querySelector('.hero-sub');
    const cta = document.querySelector('.hero-cta');
    const visual = document.querySelector('.hero-visual');
    const scrollHint = document.querySelector('.scroll-hint');

    // Staggered entrance
    if (title) setTimeout(() => title.classList.add('animate-in'), 100);
    if (tagline) setTimeout(() => tagline.classList.add('animate-in'), 500);
    if (sub) setTimeout(() => sub.classList.add('animate-in'), 900);
    if (cta) setTimeout(() => cta.classList.add('animate-in'), 1300);
    if (visual) setTimeout(() => visual.classList.add('animate-in'), 300);
    if (scrollHint) setTimeout(() => scrollHint.classList.add('animate-in'), 1700);
}

// --- Nav hide/show on scroll ---
function initNavScroll() {
    const nav = document.getElementById('nav');
    if (!nav) return;

    let lastScroll = 0;
    let ticking = false;

    window.addEventListener('scroll', () => {
        if (!ticking) {
            requestAnimationFrame(() => {
                const currentScroll = window.scrollY;
                if (currentScroll > lastScroll && currentScroll > 100) {
                    nav.classList.add('hidden');
                } else {
                    nav.classList.remove('hidden');
                }
                lastScroll = currentScroll;
                ticking = false;
            });
            ticking = true;
        }
    });
}

// --- Smooth scroll for anchor links ---
function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            const target = document.querySelector(anchor.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });
}

// --- Community Impact Counter ---
async function initImpactCounter() {
    try {
        const response = await fetch(`${EDGE_FUNCTION_BASE}/community-stats`);
        if (!response.ok) return;
        const data = await response.json();

        if (!data) return;

        const mealsEl = document.getElementById('meals-counter');
        const recipesEl = document.getElementById('recipes-counter');

        if (mealsEl) mealsEl.textContent = data.total_meals_donated.toLocaleString();
        if (recipesEl) recipesEl.textContent = data.total_generations.toLocaleString();
    } catch (err) {
        // Silently fail — counter just shows placeholder
    }
}

// --- FAQ Accordion ---
function initFAQ() {
    document.querySelectorAll('.faq-question').forEach(button => {
        button.addEventListener('click', () => {
            const item = button.parentElement;
            const isOpen = item.classList.contains('faq-item--open');

            // Close all other items
            document.querySelectorAll('.faq-item--open').forEach(openItem => {
                openItem.classList.remove('faq-item--open');
                openItem.querySelector('.faq-question').setAttribute('aria-expanded', 'false');
            });

            // Toggle clicked item
            if (!isOpen) {
                item.classList.add('faq-item--open');
                button.setAttribute('aria-expanded', 'true');
            }
        });
    });
}

// --- Initialize Everything ---
document.addEventListener('DOMContentLoaded', () => {
    initGeometricOverlay();
    initHeroAnimation();
    initScrollAnimations();
    initWaitlistForm();
    initNavScroll();
    initSmoothScroll();
    initImpactCounter();
    initFAQ();
});
