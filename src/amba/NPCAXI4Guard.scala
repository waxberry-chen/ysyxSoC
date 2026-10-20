package ysyx

import chisel3._
import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.amba.axi4._
import freechips.rocketchip.diplomacy._

// Project integration profile: validate addresses before optimized decoders.
// CPU ABI stays unchanged. The RTL deliberately supports single-beat only.
class npc_axi4_guard extends BlackBox {
  val io = IO(new Bundle {
    val clock = Input(Clock())
    val reset = Input(Reset())
    val in = Flipped(new AXI4Bundle(CPUAXI4BundleParameters()))
    val out = new AXI4Bundle(CPUAXI4BundleParameters())
  })
}
class NPCAXI4Guard(implicit p: Parameters) extends LazyModule {
  val node = AXI4IdentityNode()
  lazy val module = new LazyModuleImp(this) {
    (node.in zip node.out) foreach { case ((in, _), (out, _)) =>
      val guard = Module(new npc_axi4_guard)
      guard.io.clock := clock
      guard.io.reset := reset
      guard.io.in <> in
      out <> guard.io.out
    }
  }
}
