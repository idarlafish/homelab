import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	build: {
        minify: false,
        sourcemap: true,
        rollupOptions: {
            output: {
                compact: false
            }
        }
    }
});
