import sqlite3 from "sqlite3";
import { NftMetadata } from "./types";

// SQLite database initialization
const db = new sqlite3.Database(".cache/cache.db");

export class NftCache {
  static async init() {
    const cache = new NftCache("cache");
    await cache.createTableIfNotExists();
    return cache;
  }

  private readonly key: string;

  private constructor(key: string) {
    this.key = key;
  }

  private async createTableIfNotExists() {
    const query = `
      CREATE TABLE IF NOT EXISTS ${this.key} (
        tokenId TEXT PRIMARY KEY,
        data TEXT
      )
    `;
    await new Promise<void>((resolve, reject) => {
      db.run(query, (err) => {
        if (err) {
          console.error("Error creating table:", err);
          reject(err);
        } else {
          resolve();
        }
      });
    });
  }

  public read(tokenId: string): Promise<NftMetadata | null> {
    return new Promise((resolve, reject) => {
      const query = `SELECT data FROM ${this.key} WHERE tokenId = ?`;
      db.get(query, [tokenId], (err, row: any) => {
        if (err) {
          console.error("Error executing query:", err);
          reject(err);
        } else {
          resolve(row ? JSON.parse(row.data) : null);
        }
      });
    });
  }

  public async add(tokenId: string, metadata: NftMetadata) {
    const query = `INSERT INTO ${this.key} (tokenId, data) VALUES (?, ?)`;
    const data = JSON.stringify(metadata);

    return new Promise<void>((resolve, reject) => {
      db.run(query, [tokenId, data], (err) => {
        if (err) {
          console.error("Error executing query:", err);
          reject(err);
        } else {
          resolve();
        }
      });
    });
  }
}
