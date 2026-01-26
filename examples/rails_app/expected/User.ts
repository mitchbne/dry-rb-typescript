import type { Address } from './Address'

type User = {
  id: number;
  name: string;
  email: string;
  age: number | null;
  active: boolean;
  address: Address;
  tags: string[];
}
