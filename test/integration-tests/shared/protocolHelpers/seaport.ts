import SEAPORT_ABI from '../abis/Seaport.json'
import { BigNumber, BigNumberish } from 'ethers'
import { expandTo18DecimalsBN } from '../helpers'
import { OPENSEA_CONDUIT_KEY } from '../constants'
import fs from 'fs'
import hre from 'hardhat'
const { ethers } = hre

export const seaportOrders = JSON.parse(
  fs.readFileSync('test/integration-tests/shared/orders/Seaport.json', { encoding: 'utf8' })
)
export const seaportInterface = new ethers.utils.Interface(SEAPORT_ABI)

export type FulfillmentComponent = {
  orderIndex: BigNumberish
  itemIndex: BigNumberish
}

export type OfferItem = {
  itemType: BigNumber // enum
  token: string // address
  identifierOrCriteria: BigNumber
  startAmount: BigNumber
  endAmount: BigNumber
}

export type ConsiderationItem = OfferItem & {
  recipient: string
}

export type OrderParameters = {
  offerer: string // address,
  offer: OfferItem[]
  consideration: ConsiderationItem[]
  orderType: BigNumber // enum
  startTime: BigNumber
  endTime: BigNumber
  zoneHash: string // bytes32
  salt: BigNumber
  conduitKey: string // bytes32,
  totalOriginalConsiderationItems: BigNumber
}

export type Order = {
  parameters: OrderParameters
  signature: string
}

export type AdvancedOrder = Order & {
  numerator: BigNumber // uint120
  denominator: BigNumber // uint120
  extraData: string // bytes
}

export function getOrderParams(apiOrder: any): { order: Order; value: BigNumber } {
  delete apiOrder.protocol_data.parameters.counter
  const order = {
    parameters: apiOrder.protocol_data.parameters,
    signature: apiOrder.protocol_data.signature,
  }
  const value = calculateValue(apiOrder.protocol_data.parameters.consideration)
  return { order, value }
}

export function getAdvancedOrderParams(apiOrder: any): { advancedOrder: AdvancedOrder; value: BigNumber } {
  delete apiOrder.protocol_data.parameters.counter
  const advancedOrder = {
    parameters: apiOrder.protocol_data.parameters,
    numerator: BigNumber.from('1'),
    denominator: BigNumber.from('1'),
    signature: apiOrder.protocol_data.signature,
    extraData: '0x00',
  }
  const value = calculateValue(apiOrder.protocol_data.parameters.consideration)
  return { advancedOrder, value }
}

export function calculateValue(considerations: ConsiderationItem[]): BigNumber {
  return considerations.reduce(
    (amt: BigNumber, consideration: ConsiderationItem) => amt.add(consideration.startAmount),
    expandTo18DecimalsBN(0)
  )
}

type BuyCovensReturnData = {
  calldata: string
  advancedOrder0: AdvancedOrder
  advancedOrder1: AdvancedOrder
  value: BigNumberish
}

type MethodParameters = {
  calldata: string
  value: BigNumberish
}

export function purchaseNFTsWithSeaport(apiData: any[], recipient: string): MethodParameters {
  let advancedOrders: AdvancedOrder[] = []
  let totalValue: BigNumber = BigNumber.from(0)
  for (const order of apiData) {
    const { advancedOrder, value } = getAdvancedOrderParams(order)
    advancedOrders.push(advancedOrder)
    totalValue = totalValue.add(value)
  }

  let orderFulfillments: FulfillmentComponent[][] = advancedOrders.map((_, index) => [
    { orderIndex: index, itemIndex: 0 },
  ])
  let considerationFulFillments: FulfillmentComponent[][] = getConsiderationFulfillments(advancedOrders)

  const calldata = seaportInterface.encodeFunctionData('fulfillAvailableAdvancedOrders', [
    advancedOrders,
    [],
    orderFulfillments,
    considerationFulFillments,
    OPENSEA_CONDUIT_KEY,
    recipient,
    100, // TODO: look into making this a better number
  ])
  return { calldata, value: totalValue }
}

function getConsiderationFulfillments(orders: AdvancedOrder[]): FulfillmentComponent[][] {
  let considerationFulfillments: FulfillmentComponent[][] = []
  const considerationRecipients: string[] = []

  for (const i in orders) {
    const protocolData = orders[i]

    for (const j in protocolData.parameters.consideration) {
      const item = protocolData.parameters.consideration[j]

      if (considerationRecipients.findIndex((x) => x === item.recipient) === -1) {
        considerationRecipients.push(item.recipient)
      }

      const recipientIndex = considerationRecipients.findIndex((x) => x === item.recipient)

      if (!considerationFulfillments[recipientIndex]) {
        considerationFulfillments.push([
          {
            orderIndex: i,
            itemIndex: j,
          },
        ])
      } else {
        considerationFulfillments[recipientIndex].push({
          orderIndex: i,
          itemIndex: j,
        })
      }
    }
  }
  return considerationFulfillments
}

export function purchaseDataForTwoCovensSeaport(receipient: string): BuyCovensReturnData {
  const { advancedOrder: advancedOrder0, value: value1 } = getAdvancedOrderParams(seaportOrders[0])
  const { advancedOrder: advancedOrder1, value: value2 } = getAdvancedOrderParams(seaportOrders[1])
  const value = value1.add(value2)
  const considerationFulfillment = [
    [[0, 0]],
    [
      [0, 1],
      [1, 1],
    ],
    [
      [0, 2],
      [1, 2],
    ],
    [[1, 0]],
  ]

  const calldata = seaportInterface.encodeFunctionData('fulfillAvailableAdvancedOrders', [
    [advancedOrder0, advancedOrder1],
    [],
    [[[0, 0]], [[1, 0]]],
    considerationFulfillment,
    OPENSEA_CONDUIT_KEY,
    receipient,
    100,
  ])
  return { calldata, advancedOrder0, advancedOrder1, value }
}
