<script lang="ts">
	interface Props {
		type?: 'delete' | 'add';
		text: string;
		onClick?: () => void;
		disabled?: boolean;
	}

	let { type = 'delete', text, onClick, disabled = false }: Props = $props();

	import deleteSvg from '$lib/assets/delete.svg?raw';
</script>

<button class="action-button {type}" class:disabled onclick={onClick} title={text}>
	<span class="action-text">{text}</span>
	<span class="action-icon">
		{#if type === 'delete'}
			{@html deleteSvg}
		{:else if type === 'add'}
			"Arrived"
		{/if}
	</span>
</button>

<style>
	.action-button {
		width: 100%;
		height: 50px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: space-between;
		border: none;
		border-radius: 5px;
		box-shadow: 1px 1px 3px rgba(0, 0, 0, 0.15) inset;
		background: transparent;
	}

	.action-button,
	.action-text,
	.action-icon {
		transition: 200ms;
	}

	.action-text {
		color: white;
		font-weight: bold;
		flex-grow: 1;
	}

	.action-icon {
		height: 40px;
		width: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-grow: 1;
	}

	.action-button:hover .action-text {
		color: transparent;
	}

	.action-button:hover .action-icon {
		transform: translateX(-50%);
	}

	.action-button:focus {
		outline: none;
	}

	/* .action-button:active .action-icon svg {
 transform: scale(0.8);
} */
</style>
