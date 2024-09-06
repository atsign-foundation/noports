<script>
    export let value, depth, valueChanged;
    import Child from './Child.svelte';
</script>

<div>
    <span>Depth == {depth}: Value == {value}</span>
    <button on:click={() => {value++; valueChanged(value);}}>Increment me</button>
</div>

{#if depth < 10}
    <Child value={value} depth={depth+1} valueChanged={(v) => {value = v; valueChanged(value);}}></Child>
{/if}