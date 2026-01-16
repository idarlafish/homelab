import { Verrou } from "@verrou/core";
import { memoryStore } from "@verrou/core/drivers/memory";
import { config } from "../config.ts";

export const verrou = new Verrou({
	default: config.LOCK_STORE,
	stores: {
		memory: { driver: memoryStore() },
	},
});
